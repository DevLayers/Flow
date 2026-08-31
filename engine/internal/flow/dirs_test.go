package flow

import (
	"path/filepath"
	"testing"
)

func TestDirChainRecordAndPredict(t *testing.T) {
	dir := t.TempDir()
	dc := NewDirChain(filepath.Join(dir, "dirs.tsv"))
	dc.Load()

	// Simulate navigation: home → Programming → ArchTide (repeated)
	for i := 0; i < 5; i++ {
		dc.Record("/home/sarw", "/home/sarw/Programming")
	}
	for i := 0; i < 3; i++ {
		dc.Record("/home/sarw/Programming", "/home/sarw/Programming/ArchTide")
	}
	// Also go to quickshell sometimes
	for i := 0; i < 2; i++ {
		dc.Record("/home/sarw/Programming", "/home/sarw/Programming/quickshell")
	}

	// From Programming, ArchTide should rank above quickshell (3 > 2)
	preds := dc.PredictFrom("/home/sarw/Programming", "", 5)
	if len(preds) == 0 {
		t.Fatal("expected predictions from /home/sarw/Programming")
	}
	if preds[0].Path != "/home/sarw/Programming/ArchTide" {
		t.Fatalf("expected ArchTide first, got %s", preds[0].Path)
	}
	if preds[0].Count != 3 {
		t.Fatalf("ArchTide count wrong: %+v", preds[0])
	}

	// Prefix filter
	preds = dc.PredictFrom("/home/sarw/Programming", "Arc", 5)
	if len(preds) != 1 || preds[0].Path != "/home/sarw/Programming/ArchTide" {
		t.Fatalf("prefix filter failed: %+v", preds)
	}

	// No match
	preds = dc.PredictFrom("/nonexistent", "", 5)
	if len(preds) != 0 {
		t.Fatalf("expected empty for unknown dir")
	}
}

func TestDirChainSaveAndLoad(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "dirs.tsv")

	dc1 := NewDirChain(path)
	dc1.Record("/a", "/b")

	dc2 := NewDirChain(path)
	dc2.Load()
	preds := dc2.PredictFrom("/a", "", 5)
	if len(preds) != 1 || preds[0].Path != "/b" {
		t.Fatalf("save/load round-trip failed: %+v", preds)
	}
}
