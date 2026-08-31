// Package flow integrates Flow Terminal's command aggregates into IRIS.
//
// It reads the canonical Flow predictor aggregate file
// (~/.local/state/flow/predictor/aggregates.tsv, schema=1) which records, per
// normalized command key: count, success/fail tallies, last/first timestamps,
// and the directories the command ran in. The format is produced by
// flow_pred_encode_cmd_record in sdata/lib/flow_predictor.sh and parsed
// tolerantly here (legacy space-joined/padded rows are normalized on load).
//
// What Flow adds over IRIS's built-in frecency:
//   - success/failure rates (penalize chronically failing commands)
//   - directory-context matching from historical DIRS evidence
//   - recovery suggestions after a failing command
//   - "./" executable/script discovery in the current directory
package flow

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	// SourceTag is the spec.Suggestion Source value for Flow candidates.
	SourceTag = "flow"

	// defaultPath matches FLOW_PRED_AGGREGATES from sdata/lib/flow_predictor.sh.
	defaultPath = ".local/state/flow/predictor/aggregates.tsv"

	// scoring weights — ported 1:1 from sdata/lib/flow_predictor.sh so both
	// engines rank identically while sharing one contract.
	wPrefix       = 40.0
	wDir          = 25.0
	wDirParent    = 10.0
	wSuccess      = 15.0
	freqPerLog2   = 6.0
	freqCap       = 24.0
	recencyH1     = 10.0
	recencyD1     = 8.0
	recencyD7     = 5.0
	recencyD30    = 2.0
	failPenalty   = 12.0
	execBonus     = 6.0
	scriptBonus   = 3.0
	mtimeBonusMax = 8.0
	maxScoreCap   = 95.0

	maxDirsScanned = 16 // cap dirs-loop work per candidate
)

// Entry is one normalized C record.
type Entry struct {
	Key     string
	Count   int
	Success int
	Fail    int
	Last    int64 // unix seconds
	First   int64
	Dirs    []string // "dir:count:last_ts" triples
	Class   string
}

func (e *Entry) Total() int { return e.Success + e.Fail }

func (e *Entry) SuccessRate() float64 {
	t := e.Total()
	if t == 0 {
		return -1 // unknown
	}
	return float64(e.Success) / float64(t)
}

// Store is a lazily-loaded, mtime-checked view of aggregates.tsv.
type Store struct {
	mu       sync.RWMutex
	path     string
	entries  map[string]*Entry
	lastMod  int64
	disabled bool
}

var (
	global     *Store
	globalOnce sync.Once
)

// GlobalStore returns the process-wide store backed by the default path
// ($XDG_STATE_HOME or ~/.local/state). Safe for concurrent use; never nil.
func GlobalStore() *Store {
	globalOnce.Do(func() {
		home, err := os.UserHomeDir()
		if err != nil {
			home = "."
		}
		if x := os.Getenv("XDG_STATE_HOME"); x != "" {
			home = "" // XDG takes precedence; resolve below
			global = &Store{path: filepath.Join(x, "flow", "predictor", "aggregates.tsv")}
		}
		if home != "" {
			global = &Store{path: filepath.Join(home, defaultPath)}
		}
	})
	return global
}

// Path returns the backing file path.
func (s *Store) Path() string { return s.path }

// sanitizeInt keeps the leading digit run of s ("12abc" -> 12, "" -> 0).
// Mirrors _flow_pred_sanitize_int in flow_predictor.sh.
func sanitizeInt(s string) int {
	i := 0
	for i < len(s) && s[i] >= '0' && s[i] <= '9' {
		i++
	}
	if i == 0 {
		return 0
	}
	n, _ := strconv.Atoi(s[:i])
	return n
}

// splitTabs splits line on literal tabs preserving empty middle fields.
// Trailing empty fields collapse (matching the engine's reader semantics).
func splitTabs(line string) []string {
	parts := strings.Split(line, "\t")
	for len(parts) > 0 && parts[len(parts)-1] == "" {
		parts = parts[:len(parts)-1]
	}
	return parts
}

// parseEntry parses the raw remainder of a "C\t..." line. Handles both the
// canonical layout (>=6 tab fields) and legacy rows whose stats were
// space-joined into one padded field, optionally carrying dir triples.
func parseEntry(rest string) (*Entry, bool) {
	fields := splitTabs(rest)
	e := &Entry{}
	if len(fields) == 0 {
		return nil, false
	}
	e.Key = fields[0]
	if e.Key == "" {
		return nil, false
	}

	if len(fields) >= 6 {
		// canonical / positional: key count success fail last first [dirs] [class]
		e.Count = sanitizeInt(fields[1])
		e.Success = sanitizeInt(fields[2])
		e.Fail = sanitizeInt(fields[3])
		e.Last = int64(sanitizeInt(fields[4]))
		e.First = int64(sanitizeInt(fields[5]))
		if len(fields) >= 7 && fields[6] != "" {
			e.Dirs = strings.Split(fields[6], ",")
		}
		if len(fields) >= 8 {
			e.Class = fields[7]
		}
		return e, true
	}

	// legacy blob: "count success fail last first [/dir:n:ts ...]" + padding
	blob := ""
	if len(fields) >= 2 {
		blob = fields[1]
	}
	nums := 0
	for _, tok := range strings.Fields(blob) {
		if strings.HasPrefix(tok, "/") {
			e.Dirs = append(e.Dirs, tok)
			continue
		}
		if nums < 5 {
			v := sanitizeInt(tok)
			switch nums {
			case 0:
				e.Count = v
			case 1:
				e.Success = v
			case 2:
				e.Fail = v
			case 3:
				e.Last = int64(v)
			case 4:
				e.First = int64(v)
			}
			nums++
		}
	}
	return e, true
}

// load (re)reads the aggregate file if it changed since last load.
func (s *Store) loadLocked() {
	if s.disabled {
		return
	}
	st, err := os.Stat(s.path)
	if err != nil {
		return
	}
	mt := st.ModTime().UnixNano()
	if s.entries != nil && mt == s.lastMod {
		return
	}
	f, err := os.Open(s.path)
	if err != nil {
		return
	}
	defer f.Close()

	entries := make(map[string]*Entry, 2048)
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		line := sc.Text()
		if line == "" || line[0] == '#' {
			continue
		}
		kindEnd := strings.IndexByte(line, '\t')
		if kindEnd <= 0 || line[0] != 'C' {
			continue // T/W/R records handled by IRIS's own transition learning
		}
		if e, ok := parseEntry(line[kindEnd+1:]); ok {
			// last-wins: the zsh recorder appends refreshed records for keys
			// it has already written; newer lines must override older ones.
			entries[e.Key] = e
		}
	}
	s.entries = entries
	s.lastMod = mt
}

// snapshot returns the current entry map, loading if stale.
func (s *Store) snapshot() map[string]*Entry {
	s.mu.RLock()
	if s.entries != nil && s.lastMod == s.recheckMtime() {
		m := s.entries
		s.mu.RUnlock()
		return m
	}
	s.mu.RUnlock()

	s.mu.Lock()
	defer s.mu.Unlock()
	s.loadLocked()
	return s.entries
}

func (s *Store) recheckMtime() int64 {
	st, err := os.Stat(s.path)
	if err != nil {
		return s.lastMod
	}
	return st.ModTime().UnixNano()
}

// Lookup returns stats for an exact command key, or nil.
func (s *Store) Lookup(key string) *Entry {
	m := s.snapshot()
	return m[key]
}

// SuccessRate returns -1 when unknown, else [0..1].
func (s *Store) SuccessRate(cmd string) float64 {
	if e := s.Lookup(cmd); e != nil {
		return e.SuccessRate()
	}
	return -1
}

func recencyBonus(last int64, now int64) float64 {
	age := now - last
	switch {
	case age < 3600:
		return recencyH1
	case age < 86400:
		return recencyD1
	case age < 604800:
		return recencyD7
	case age < 2592000:
		return recencyD30
	}
	return 0
}

func freqBonus(count int) float64 {
	f := 0.0
	for c := count; c > 1; c >>= 1 {
		f += freqPerLog2
	}
	if f > freqCap {
		f = freqCap
	}
	return f
}

// score computes the Flow rank for an entry against cwd/query.
// Mirrors _flow_pred_score_core in sdata/lib/flow_predictor.sh.
func (s *Store) score(e *Entry, cwd, query string, now int64) (float64, []string) {
	var reasons []string
	score := 0.0
	keylen := len([]rune(e.Key))
	if keylen == 0 {
		return 0, nil
	}
	qlen := len([]rune(query))

	if query != "" {
		if !strings.HasPrefix(e.Key, query) {
			return 0, nil // hard prefix gate like the engine
		}
		score += wPrefix + float64(qlen*100/keylen)/4
		reasons = append(reasons, "prefix")
	} else {
		// empty query requires a context anchor (dir match / recent use)
		anchored := false
		if cwd != "" && dirsMatch(e.Dirs, cwd) {
			score += wDir
			anchored = true
			reasons = append(reasons, "dir")
		}
		if !anchored && e.Last > 0 && now-e.Last < 86400 {
			anchored = true
			reasons = append(reasons, "recent")
		}
		if !anchored {
			return 0, nil // context-less stale rows stay out entirely
		}
	}

	if cwd != "" {
		if hasExactDir(e.Dirs, cwd) {
			if query != "" {
				score += wDir
				reasons = append(reasons, "dir")
			}
			// per-dir frequency sub-bonus, capped
			fb := float64(dirCount(e.Dirs, cwd)) * freqPerLog2
			if fb > freqCap {
				fb = freqCap
			}
			score += fb
		} else if isUnderRecordedDir(e.Dirs, cwd) && query != "" {
			score += wDirParent
			reasons = append(reasons, "parent_dir")
		}
	}

	if t := e.Total(); t > 0 {
		score += float64(e.Success*wSuccessPoints()) / float64(t)
		if t >= 3 && e.Fail > 0 && e.Fail*100/t >= 50 {
			score -= failPenalty
			reasons = append(reasons, "fails_a_lot")
		}
	}
	score += freqBonus(e.Count)
	score += recencyBonus(e.Last, now)
	return score, reasons
}

func wSuccessPoints() int { return 15 }

func hasExactDir(dirs []string, cwd string) bool {
	needle := cwd + ":"
	for _, d := range dirs {
		if d == cwd || strings.HasPrefix(d, needle) {
			return true
		}
	}
	return false
}

func dirCount(dirs []string, cwd string) int {
	needle := cwd + ":"
	for _, d := range dirs {
		if d == cwd || strings.HasPrefix(d, needle) {
			rest := strings.TrimPrefix(strings.TrimPrefix(d, cwd), ":")
			if i := strings.IndexByte(rest, ':'); i >= 0 {
				rest = rest[:i]
			}
			if n, err := strconv.Atoi(rest); err == nil && n > 0 {
				return n
			}
			return 1
		}
	}
	return 0
}

// isUnderRecordedDir reports whether cwd lives under any recorded dir.
func isUnderRecordedDir(dirs []string, cwd string) bool {
	cwdPrefix := cwd + "/"
	for i, d := range dirs {
		if i >= maxDirsScanned {
			break
		}
		dpath, _, _ := strings.Cut(d, ":")
		if dpath != "" && dpath != "/" && strings.HasPrefix(cwdPrefix, dpath+"/") {
			return true
		}
	}
	return false
}

func dirsMatch(dirs []string, cwd string) bool {
	return hasExactDir(dirs, cwd) || isUnderRecordedDir(dirs, cwd)
}

// Suggest returns ranked Flow candidates for cwd/query, best first.
// query may be empty (context mode). limit caps results.
func (s *Store) Suggest(cwd, query string, limit int) []*Candidate {
	now := time.Now().Unix()
	m := s.snapshot()
	out := make([]*Candidate, 0, limit)
	for _, e := range m {
		sc, reasons := s.score(e, cwd, query, now)
		if sc <= 0 {
			continue
		}
		out = append(out, &Candidate{Entry: e, Score: sc, Reasons: reasons})
	}
	// sort desc by score, tie-break alphabetical for determinism
	for i := 1; i < len(out); i++ {
		for j := i; j > 0; j-- {
			a, b := out[j], out[j-1]
			if a.Score > b.Score || (a.Score == b.Score && a.Key < b.Key) {
				out[j], out[j-1] = out[j-1], out[j]
			} else {
				break
			}
		}
	}
	if len(out) > limit {
		out = out[:limit]
	}
	return out
}

// Candidate pairs an entry with its computed rank.
type Candidate struct {
	*Entry
	Score   float64
	Reasons []string
}

// String renders a debug line.
func (c *Candidate) String() string {
	return fmt.Sprintf("%s score=%.0f [%s]", c.Key, c.Score, strings.Join(c.Reasons, ","))
}

// SnapshotEntries returns a copy of the current entry map values (for
// cross-package reads; callers must not mutate).
func (s *Store) SnapshotEntries() map[string]*Entry {
	return s.snapshot()
}

// HasDir reports whether this command has recorded evidence in dir.
func (e *Entry) HasDir(dir string) bool {
	if dir == "" || len(e.Dirs) == 0 {
		return false
	}
	needle := dir + ":"
	for _, d := range e.Dirs {
		if d == dir || strings.HasPrefix(d, needle) {
			return true
		}
	}
	return false
}

// AllTransitions parses all T records from the aggregate file (last-wins).
func (s *Store) AllTransitions() map[string]*TEntry {
	s.mu.RLock()
	path := s.path
	s.mu.RUnlock()
	return readTRecords(path)
}

// PrevOf extracts the prev skeleton from a pair key.
func (t *TEntry) PrevOf(pair string) string {
	if i := strings.IndexByte(pair, 0x1f); i >= 0 {
		return pair[:i]
	}
	return ""
}

// NextOf extracts the next skeleton from a pair key.
func (t *TEntry) NextOf(pair string) string {
	if i := strings.IndexByte(pair, 0x1f); i >= 0 {
		return pair[i+1:]
	}
	return ""
}

// DirFrecency returns how many distinct commands have been executed in the
// given directory (derived from C-record Dirs evidence).
func (s *Store) DirFrecency(dir string) int {
	count := 0
	for _, e := range s.SnapshotEntries() {
		if e.HasDir(dir) {
			count++
		}
	}
	return count
}

// DirFrecencyBoost returns a score multiplier for candidates whose
// destination directory is a high-traffic project root. Used to rank
// "cd ArchTide" above "cd Programming" when both match a query prefix.
func (s *Store) DirFrecencyBoost(dir string) float64 {
	count := s.DirFrecency(dir)
	if count == 0 {
		return 0
	}
	// log scale: 10 visits = +2.4, 100 = +4.6, 500 = +6.2
	return math.Log1p(float64(count)) * 3.0
}
