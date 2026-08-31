package flow

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

// DirChain learns directory-to-directory navigation patterns.
// It builds a Markov model of how you move between directories,
// then predicts your likely destination from your current location.
//
// Data source: every chpwd event (cd, z, pushd) fires a CWD update.
// The engine records (from → to) pairs, building a transition graph.
type DirChain struct {
	mu       sync.RWMutex
	trans    map[string]map[string]*dirEdge // from → to → edge
	path     string                         // persistence file
	lastMod  int64
	totalObs int
}

type dirEdge struct {
	Count  int
	LastTs int64
}

// NewDirChain creates an empty transition model backed by path.
func NewDirChain(path string) *DirChain {
	return &DirChain{trans: make(map[string]map[string]*dirEdge), path: path}
}

// Record observes a directory transition from→to.
func (dc *DirChain) Record(from, to string) {
	if from == "" || to == "" || from == to {
		return
	}
	dc.mu.Lock()
	defer dc.mu.Unlock()

	if dc.trans[from] == nil {
		dc.trans[from] = make(map[string]*dirEdge)
	}
	if dc.trans[from][to] == nil {
		dc.trans[from][to] = &dirEdge{}
	}
	dc.trans[from][to].Count++
	dc.trans[from][to].LastTs = time.Now().Unix()
	dc.totalObs++

	// append to disk immediately — no separate Save step needed
	os.MkdirAll(filepath.Dir(dc.path), 0700)
	if f, err := os.OpenFile(dc.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600); err == nil {
		fmt.Fprintf(f, "D\t%s\t%s\t%d\n", from, to, dc.trans[from][to].LastTs)
		f.Close()
	}
}

// Load reads persisted transitions from disk.
func (dc *DirChain) Load() {
	data, err := os.ReadFile(dc.path)
	if err != nil {
		return
	}
	dc.mu.Lock()
	defer dc.mu.Unlock()
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || !strings.HasPrefix(line, "D\t") {
			continue
		}
		parts := strings.SplitN(line[2:], "\t", 3)
		if len(parts) != 3 {
			continue
		}
		from := parts[0]
		to := parts[1]
		var ts int64
		fmt.Sscanf(parts[2], "%d", &ts)
		if dc.trans[from] == nil {
			dc.trans[from] = make(map[string]*dirEdge)
		}
		if dc.trans[from][to] == nil {
			dc.trans[from][to] = &dirEdge{Count: 0, LastTs: ts}
		}
		dc.trans[from][to].Count++ // aggregate across duplicate lines
		if ts > dc.trans[from][to].LastTs {
			dc.trans[from][to].LastTs = ts
		}
	}
}

// PredictFrom returns likely next directories from the given directory,
// ranked by visit frequency. Only returns destinations containing prefix
// (if non-empty). Results sorted by count desc.
func (dc *DirChain) PredictFrom(from string, prefix string, limit int) []DirPrediction {
	dc.mu.RLock()
	targets := dc.trans[from]
	dc.mu.RUnlock()

	if len(targets) == 0 {
		return nil
	}
	type scored struct {
		path  string
		count int
	}
	all := make([]scored, 0, len(targets))
	for to, edge := range targets {
		if prefix != "" && !strings.HasPrefix(filepath.Base(to), prefix) && !strings.HasPrefix(to, prefix) {
			continue
		}
		all = append(all, scored{path: to, count: edge.Count})
	}
	sort.SliceStable(all, func(i, j int) bool { return all[i].count > all[j].count })
	if len(all) > limit {
		all = all[:limit]
	}
	out := make([]DirPrediction, 0, len(all))
	for _, s := range all {
		out = append(out, DirPrediction{Path: s.path, Count: s.count})
	}
	return out
}

// DirPrediction is one ranked directory destination.
type DirPrediction struct {
	Path  string
	Count int
}

// TopDestination returns the single most-frequent next directory from `from`,
// optionally filtered by prefix. Returns empty string if none.
func (dc *DirChain) TopDestination(from, prefix string) string {
	preds := dc.PredictFrom(from, prefix, 1)
	if len(preds) == 0 {
		return ""
	}
	return preds[0].Path
}
