package scoring

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func testStore(t *testing.T) *FrecencyStore {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "aggregates.tsv")
	if err := os.WriteFile(path, []byte("# flow-predictor schema=1\n"), 0600); err != nil {
		t.Fatal(err)
	}
	saved := frecencyInstance
	fs, _ := NewFrecencyStore(path)
	frecencyInstance = fs
	t.Cleanup(func() { frecencyInstance = saved })
	return fs
}

// point the flow global store at the test file too
func pointFlow(t *testing.T, fs *FrecencyStore) {
	t.Helper()
	_ = fs
}

func TestFrecencyStore_RecordAndQueryLocal(t *testing.T) {
	fs := testStore(t)
	ctx := context.Background()

	// record twice in /repo/a (success), once failing elsewhere
	if err := fs.Record(ctx, "git status", "/repo/a", 0); err != nil {
		t.Fatal(err)
	}
	if err := fs.Record(ctx, "git status", "/repo/a", 0); err != nil {
		t.Fatal(err)
	}
	if err := fs.Record(ctx, "git status", "/elsewhere", 1); err != nil {
		t.Fatal(err)
	}

	local, err := fs.QueryLocal(ctx, "/repo/a", "", 10)
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, e := range local {
		if e.Cmd == "git status" && e.Count >= 2 {
			found = true
		}
	}
	if !found {
		t.Fatalf("local query missing dir-evidenced entry: %+v", local)
	}

	global, err := fs.QueryGlobal(ctx, "git st", 10)
	if err != nil || len(global) == 0 {
		t.Fatalf("global query failed: %v %v", global, err)
	}
}

func TestFrecencyStore_RawScoreDistribution(t *testing.T) {
	fs := &FrecencyStore{}
	recent := fs.RawScore(5, time.Now())
	old := fs.RawScore(5, time.Now().Add(-40*24*time.Hour))
	if recent <= old {
		t.Fatalf("recency decay broken: recent=%f old=%f", recent, old)
	}
}

func TestFrecencyStore_TransitionsRoundTrip(t *testing.T) {
	fs := testStore(t)
	ctx := context.Background()
	if err := fs.RecordTransition(ctx, "git status", "git add", "/repo/a", 0); err != nil {
		t.Fatal(err)
	}
	if err := fs.RecordTransition(ctx, "git status", "git add", "/repo/a", 0); err != nil {
		t.Fatal(err)
	}
	trans, ok := fs.QueryTransitionsWithFallback(ctx, "git status", "/repo/a")
	if !ok || len(trans) == 0 {
		t.Fatalf("expected transition, got ok=%v entries=%v", ok, trans)
	}
	if trans[0].Count < 2 || trans[0].NextSkeleton != "git add" {
		t.Fatalf("bad transition: %+v", trans[0])
	}
	// depth fallback: partial skeleton still resolves
	trans2, ok2 := fs.QueryTransitionsWithFallback(ctx, "git status extra words", "/repo/a")
	if !ok2 || len(trans2) == 0 {
		t.Fatalf("depth fallback failed: ok=%v", ok2)
	}
}

func TestFrecencyStore_NilReceiver(t *testing.T) {
	var fs *FrecencyStore
	if err := fs.Record(context.Background(), "x", "/", 0); err != nil {
		t.Fatal(err)
	}
	if _, err := fs.QueryLocal(context.Background(), "/", "", 5); err != nil {
		t.Fatal(err)
	}
}
