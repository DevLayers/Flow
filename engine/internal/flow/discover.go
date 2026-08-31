package flow

import (
	"os"
	"path/filepath"
	"strings"
)

var scriptExts = map[string]bool{
	".sh": true, ".bash": true, ".zsh": true,
	".py": true, ".pl": true, ".rb": true, ".fish": true,
}

// ScriptCandidate is one discovered executable/script in the cwd.
type ScriptCandidate struct {
	Path    string // as typed: "./build.sh"
	IsExec  bool
	ModTime int64
}

// DiscoverLocal scans dir (flat, no recursion) for regular files that are
// executable or carry a script extension and match the typed prefix after
// "./" (rest may be empty). Returns at most limit candidates. Nothing is
// executed; stat-only.
func DiscoverLocal(dir, rest string, limit int) []ScriptCandidate {
	entries, err := os.ReadDir(dir)
	if err != nil || len(entries) == 0 {
		return nil
	}
	now := timeNowUnix()
	out := make([]ScriptCandidate, 0, 8)
	scanned := 0
	for _, de := range entries {
		if scanned >= 400 || len(out) >= limit {
			break
		}
		name := de.Name()
		if !strings.HasPrefix(name, rest) {
			continue
		}
		if de.IsDir() {
			continue
		}
		scanned++
		info, err := de.Info()
		if err != nil || !info.Mode().IsRegular() {
			continue
		}
		isExec := info.Mode().Perm()&0111 != 0
		ext := strings.ToLower(filepath.Ext(name))
		if !isExec && !scriptExts[ext] {
			continue
		}
		out = append(out, ScriptCandidate{
			Path:    "./" + name,
			IsExec:  isExec,
			ModTime: info.ModTime().Unix(),
		})
		_ = now
	}
	return out
}

// ScoreScript ranks a discovered script against the typed prefix, blending
// any historical usage recorded in aggregates for the same key.
func (s *Store) ScoreScript(dir string, cand ScriptCandidate, query string) (float64, []string) {
	keylen := len([]rune(cand.Path))
	if keylen == 0 {
		return 0, nil
	}
	qlen := len([]rune(query))
	score := wPrefix + float64(qlen*100/keylen)/4
	reasons := []string{"prefix"}
	if cand.IsExec {
		score += execBonus
		reasons = append(reasons, "exec")
	} else {
		score += scriptBonus
		reasons = append(reasons, "script")
	}
	age := timeNowUnix() - cand.ModTime
	switch {
	case age < 3600:
		score += mtimeBonusMax
		reasons = append(reasons, "recent")
	case age < 86400:
		score += mtimeBonusMax * 0.75
		reasons = append(reasons, "recent")
	case age < 604800:
		score += mtimeBonusMax * 0.4
	}
	// blend prior success stats for this exact command key
	if e := s.Lookup(cand.Path); e != nil && e.Total() > 0 {
		sb := float64(e.Success*wSuccessPoints()) / float64(e.Total())
		if sb > 12 {
			sb = 12
		}
		score += sb
		reasons = append(reasons, "used_before")
	}
	if score > maxScoreCap {
		score = maxScoreCap
	}
	return score, reasons
}

// SuggestScripts merges discovery + scoring for "./..." queries.
func (s *Store) SuggestScripts(cwd, query string, limit int) []*Candidate {
	if !strings.HasPrefix(query, "./") {
		return nil
	}
	rest := strings.TrimPrefix(query, "./")
	found := DiscoverLocal(cwd, rest, limit*3)
	out := make([]*Candidate, 0, len(found))
	for _, c := range found {
		sc, reasons := s.ScoreScript(cwd, c, query)
		if sc <= 0 {
			continue
		}
		e := s.Lookup(c.Path)
		if e == nil {
			e = &Entry{Key: c.Path}
		}
		out = append(out, &Candidate{Entry: e, Score: sc, Reasons: reasons})
	}
	// insertion sort desc by score (small n)
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && out[j].Score > out[j-1].Score; j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	if len(out) > limit {
		out = out[:limit]
	}
	return out
}
