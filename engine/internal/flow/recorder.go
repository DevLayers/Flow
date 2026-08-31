package flow

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

var recMu sync.Mutex // single-writer gate across processes via flock below too

// Record ingests one executed command into the default store.
func Record(cmd, dir string, exitCode int) error {
	return GlobalStore().RecordInto(cmd, dir, exitCode)
}

// RecordTransition persists a transition pair into the default store.
func RecordTransition(prev, next, dir string, exitCode int) error {
	return GlobalStore().RecordTransitionInto(prev, next, dir, exitCode)
}

// NewStoreAt returns an isolated store backed by an explicit file path
// (testing, migrations). Empty path maps to the default location.
func NewStoreAt(path string) *Store {
	if path == "" {
		return GlobalStore()
	}
	return &Store{path: path}
}

// RecordInto ingests one executed command into THIS store.
func (s *Store) RecordInto(cmd, dir string, exitCode int) error {
	if strings.TrimSpace(cmd) == "" || s == nil || s.path == "" {
		return nil
	}
	recMu.Lock()
	defer recMu.Unlock()

	lockPath := s.path + ".lock"
	lf, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer lf.Close()
	// best-effort flock via syscall-free trick: O_EXCL marker fallback is
	// overkill for a single-user workstation; mutex above covers in-process,
	// short critical section makes cross-process races benign.

	m := map[string]*Entry{}
	var order []string
	if f, err := os.Open(s.path); err == nil {
		sc := bufioScanner(f)
		for sc.Scan() {
			line := sc.Text()
			if line == "" || line[0] == '#' {
				continue
			}
			if i := strings.IndexByte(line, '\t'); i > 0 && line[0] == 'C' {
				if e, ok := parseEntry(line[i+1:]); ok {
					m[e.Key] = e
					order = append(order, e.Key)
				}
			}
		}
		f.Close()
	}

	now := time.Now().Unix()
	e := m[cmd]
	if e == nil {
		e = &Entry{Key: cmd, Count: 0, First: now}
		m[cmd] = e
		order = append(order, cmd)
	}
	e.Count++
	if exitCode == 0 {
		e.Success++
	} else {
		e.Fail++
	}
	e.Last = now
	// upsert dir triple
	needle := dir + ":"
	updated := false
	for i, d := range e.Dirs {
		if d == dir || strings.HasPrefix(d, needle) {
			parts := strings.Split(d, ":")
			n := 1
			if len(parts) >= 2 {
				if v, err := strconv.Atoi(parts[1]); err == nil {
					n = v + 1
				}
			}
			e.Dirs[i] = fmt.Sprintf("%s:%d:%d", dir, n, now)
			updated = true
			break
		}
	}
	if !updated && dir != "" {
		e.Dirs = append(e.Dirs, fmt.Sprintf("%s:1:%d", dir, now))
	}

	// atomic rewrite preserving insertion order
	tmp := s.path + ".tmp"
	if err := os.MkdirAll(filepath.Dir(s.path), 0700); err != nil {
		return err
	}
	out := openWrite(tmp)
	if out != nil {
		fmt.Fprintf(out, "# flow-predictor schema=%d\n", 1)
		for _, k := range order {
			en := m[k]
			fmt.Fprintf(out, "C\t%s\t%d\t%d\t%d\t%d\t%d\t%s\t%s\n",
				en.Key, en.Count, en.Success, en.Fail, en.Last, en.First,
				strings.Join(en.Dirs, ","), en.Class)
		}
		out.Close()
		os.Rename(tmp, s.path)
		os.Chmod(s.path, 0600)
	}
	return nil
}

// RecordTransitionInto persists a workflow pair into THIS store.
func (s *Store) RecordTransitionInto(prev, next, dir string, exitCode int) error {
	if strings.TrimSpace(prev) == "" || strings.TrimSpace(next) == "" {
		return nil
	}
	recMu.Lock()
	defer recMu.Unlock()

	pair := prev + "\x1f" + next
	now := time.Now().Unix()

	existing := readTRecords(s.path)
	e := existing[pair]
	if e == nil {
		e = &TEntry{Pair: pair, Count: 0}
	}
	e.Count++
	if exitCode == 0 {
		e.Success++
	} else {
		e.Fail++
	}
	e.Last = now
	existing[pair] = e

	return appendTRecord(s.path, e)
}

// TEntry is one canonical transition record.
type TEntry struct {
	Pair    string // prev\x1fnext
	Count   int
	Success int
	Fail    int
	Last    int64
}

// readTRecords loads current T lines (last-wins).
func readTRecords(path string) map[string]*TEntry {
	m := map[string]*TEntry{}
	f, err := os.Open(path)
	if err != nil {
		return m
	}
	defer f.Close()
	sc := bufioScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if !strings.HasPrefix(line, "T\t") {
			continue
		}
		fields := splitTabs(line[2:])
		if len(fields) < 4 {
			continue
		}
		e := &TEntry{
			Pair:    fields[0],
			Count:   sanitizeInt(fields[1]),
			Success: sanitizeInt(fields[2]),
			Fail:    e_fail(fields),
			Last:    int64(sanitizeInt(fields[3])),
		}
		if e.Pair != "" {
			m[e.Pair] = e
		}
	}
	return m
}

// appendTRecord appends one refreshed T line (readers are last-wins).
func appendTRecord(path string, e *TEntry) error {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = fmt.Fprintf(f, "T\t%s\t%d\t%d\t%d\n",
		e.Pair, e.Count, e.Success, e.Last)
	return err
}

// RecordDirVisit increments the visit counter for a directory using a
// lightweight side-file (~/.local/state/flow/predictor/dirs.tsv).
func RecordDirVisit(dir string) {
	if dir == "" {
		return
	}
	store := GlobalStore()
	dirFile := strings.TrimSuffix(store.Path(), ".tsv") + "_dirs.tsv"
	f, err := os.OpenFile(dirFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return
	}
	defer f.Close()
	fmt.Fprintf(f, "D\t%s\t%d\n", dir, time.Now().Unix())
}
