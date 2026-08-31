package scoring

// FrecencyStore — Flow Engine edition.
//
// The upstream implementation backed this store with SQLite. Flow consolidated
// all intelligence into the single aggregates.tsv store (internal/flow):
// commands (C), transitions (T), workflows (W), recoveries (R). This file now
// adapts that store to the same public API the scoring pipeline expects, so
// CollectSignals and the wrapper are untouched.
//
// There is no database anymore: reads come from flow's mtime-checked snapshot,
// writes go through flow's atomic recorder. Single source of truth.

import (
	"context"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/SrwR16/flow-engine/internal/flow"
)

type FrecencyEntry struct {
	Cmd      string
	Cwd      string
	Count    int
	LastUsed time.Time
	RawScore float64
}

type TransitionEntry struct {
	PrevSkeleton string
	NextSkeleton string
	Cwd          string
	Count        int
	LastUsed     time.Time
}

type FrecencyStore struct {
	fs *flow.Store // isolated instance (tests) or the shared default
}

func NewFrecencyStore(path string) (*FrecencyStore, error) {
	return &FrecencyStore{fs: flow.NewStoreAt(path)}, nil
}

var (
	frecencyOnce     sync.Once
	frecencyInstance *FrecencyStore
)

func GetFrecencyStore() (*FrecencyStore, error) {
	frecencyOnce.Do(func() {
		store, err := NewFrecencyStore("")
		if err != nil {
			return
		}
		frecencyInstance = store
	})
	return frecencyInstance, nil
}

func CloseGlobalFrecencyStore() {}

// Record ingests one executed command into the Flow store.
func (f *FrecencyStore) Record(ctx context.Context, cmd, cwd string, exitCode int) error {
	if f == nil || strings.TrimSpace(cmd) == "" {
		return nil
	}
	return f.fs.RecordInto(cmd, cwd, exitCode)
}

// RecordTransition persists a workflow pair into the Flow store.
func (f *FrecencyStore) RecordTransition(ctx context.Context, prevSkeleton, nextSkeleton, cwd string, nextExitCode int) error {
	if f == nil {
		return nil
	}
	return f.fs.RecordTransitionInto(prevSkeleton, nextSkeleton, cwd, nextExitCode)
}

// RawScore mirrors upstream decay buckets so ranking behavior is preserved.
func (f *FrecencyStore) RawScore(count int, lastUsed time.Time) float64 {
	if count <= 0 {
		return 0
	}
	age := max(time.Since(lastUsed), 0)
	var weight float64
	switch {
	case age <= time.Hour:
		weight = 100.0
	case age <= 24*time.Hour:
		weight = 50.0
	case age <= 7*24*time.Hour:
		weight = 20.0
	case age <= 30*24*time.Hour:
		weight = 5.0
	default:
		weight = 1.0
	}
	return float64(count) * weight
}

func (f *FrecencyStore) Close() error { return nil }

// QueryLocal returns prefix-matched commands with directory evidence for cwd,
// ranked by RawScore desc. Local means: this command historically ran HERE.
func (f *FrecencyStore) QueryLocal(ctx context.Context, cwd, prefix string, limit int) ([]FrecencyEntry, error) {
	if f == nil || f.fs == nil {
		return nil, nil
	}
	if limit <= 0 {
		limit = 50
	}
	var out []FrecencyEntry
	for _, e := range f.fs.SnapshotEntries() {
		if prefix != "" && !strings.HasPrefix(e.Key, prefix) {
			continue
		}
		if !e.HasDir(cwd) {
			continue
		}
		out = append(out, FrecencyEntry{
			Cmd:      e.Key,
			Cwd:      cwd,
			Count:    e.Count,
			LastUsed: time.Unix(e.Last, 0),
			RawScore: f.RawScore(e.Count, time.Unix(e.Last, 0)),
		})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].RawScore > out[j].RawScore })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

// QueryGlobal returns prefix-matched commands regardless of directory.
func (f *FrecencyStore) QueryGlobal(ctx context.Context, prefix string, limit int) ([]FrecencyEntry, error) {
	if f == nil || f.fs == nil {
		return nil, nil
	}
	if limit <= 0 {
		limit = 50
	}
	var out []FrecencyEntry
	for _, e := range f.fs.SnapshotEntries() {
		if prefix != "" && !strings.HasPrefix(e.Key, prefix) {
			continue
		}
		out = append(out, FrecencyEntry{
			Cmd:      e.Key,
			Count:    e.Count,
			LastUsed: time.Unix(e.Last, 0),
			RawScore: f.RawScore(e.Count, time.Unix(e.Last, 0)),
		})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].RawScore > out[j].RawScore })
	if len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

// QueryTransitionsWithFallback returns learned next-steps for prevSkeleton,
// preferring exact matches; depth-falls back on shorter prefixes like
// upstream. Cwd preference: transitions recorded per-pair only (Flow keeps
// them global), so locality filtering is deferred to the caller's scoring.
func (f *FrecencyStore) QueryTransitionsWithFallback(ctx context.Context, prevSkeleton, cwd string) ([]TransitionEntry, bool) {
	if f == nil || f.fs == nil {
		return nil, false
	}
	prevSkeleton = strings.TrimSpace(prevSkeleton)
	if prevSkeleton == "" {
		return nil, false
	}
	trans := f.fs.AllTransitions()

	parts := strings.Fields(prevSkeleton)
	for len(parts) > 0 {
		key := strings.Join(parts, " ")
		var out []TransitionEntry
		for pair, e := range trans {
			if e.PrevOf(pair) != key || e.Count <= 0 {
				continue
			}
			next := e.NextOf(pair)
			if next == "" {
				continue
			}
			out = append(out, TransitionEntry{
				PrevSkeleton: key,
				NextSkeleton: next,
				Cwd:          cwd,
				Count:        e.Count,
				LastUsed:     time.Unix(e.Last, 0),
			})
		}
		if len(out) > 0 {
			sort.SliceStable(out, func(i, j int) bool { return out[i].Count > out[j].Count })
			if len(out) > 20 {
				out = out[:20]
			}
			return out, true
		}
		parts = parts[:len(parts)-1] // depth fallback: drop last word
	}
	return nil, false
}
