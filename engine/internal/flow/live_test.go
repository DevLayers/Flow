package flow

import (
	"os"
	"testing"
)

func TestLiveAggregates(t *testing.T) {
	s := GlobalStore()
	if _, err := os.Stat(s.Path()); err != nil {
		t.Skip("no aggregates.tsv on this machine")
	}
	const cwd = "/home/sarw/Programming/ArchTide"

	t.Run("context mode (empty query)", func(t *testing.T) {
		got := s.Suggest(cwd, "", 5)
		if len(got) == 0 {
			t.Fatal("expected contextual candidates in repo dir with real aggregates")
		}
		for _, c := range got {
			t.Logf("%6.0f  %-60s [%v] %d ok/%d fail", c.Score, c.Key, c.Reasons, c.Success, c.Fail)
		}
	})

	t.Run("prefix query", func(t *testing.T) {
		got := s.Suggest(cwd, "git ", 5)
		for _, c := range got {
			t.Logf("%6.0f  %s  [%v]", c.Score, c.Key, c.Reasons)
			if c.Score <= 0 {
				t.Fatalf("candidate %q leaked with score<=0", c.Key)
			}
		}
	})

	t.Run("./ discovery", func(t *testing.T) {
		got := s.SuggestScripts(cwd, "./", 8)
		if len(got) == 0 {
			t.Log("no executables matched in cwd (ok on bare checkouts)")
			return
		}
		for _, c := range got {
			t.Logf("%6.0f  %s  [%v]", c.Score, c.Key, c.Reasons)
			if !hasPrefixFold(c.Key, "./") {
				t.Fatalf("script candidate %q lacks ./ prefix", c.Key)
			}
		}
	})
}

func hasPrefixFold(s, p string) bool {
	return len(s) >= len(p) && equalFold(s[:len(p)], p)
}

func equalFold(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := 0; i < len(a); i++ {
		ca, cb := a[i], b[i]
		if 'A' <= ca && ca <= 'Z' {
			ca += 32
		}
		if 'A' <= cb && cb <= 'Z' {
			cb += 32
		}
		if ca != cb {
			return false
		}
	}
	return true
}
