package flow

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRecordAndTransitionRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "aggregates.tsv")
	os.WriteFile(path, []byte("# flow-predictor schema=1\n"), 0600)

	saved := GlobalStore()
	global = &Store{path: path}
	defer func() { global = saved }()

	if err := Record("git status", "/repo", 0); err != nil {
		t.Fatalf("Record: %v", err)
	}
	if err := Record("git status", "/repo", 1); err != nil {
		t.Fatalf("Record: %v", err)
	}
	if err := RecordTransition("git status", "git add", "/repo", 0); err != nil {
		t.Fatalf("RecordTransition: %v", err)
	}

	data, _ := os.ReadFile(path)
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) < 3 {
		t.Fatalf("expected header+2 records, got:\n%s", data)
	}
	var cLine, tLine string
	for _, l := range lines {
		if strings.HasPrefix(l, "C\tgit status") {
			cLine = l
		}
		if strings.HasPrefix(l, "T\t") {
			tLine = l
		}
	}
	if cLine == "" || !strings.Contains(cLine, "\t2\t1\t1\t") {
		t.Errorf("bad C record (want count=2 success=1 fail=1): %q", cLine)
	}
	if tLine == "" || !strings.Contains(tLine, "git status\x1fgit add\t1\t1\t") {
		t.Errorf("bad T record: %q", tLine)
	}
	// dirs evidence accumulated
	if !strings.Contains(cLine, "/repo:2:") {
		t.Errorf("dir triple not accumulated: %q", cLine)
	}
}
