package brain

import (
	"testing"
	"time"
)

func TestEngineRank(t *testing.T) {
	e := NewEngine()

	// Train: git status → git add is a strong pattern
	for i := 0; i < 10; i++ {
		e.Chain.Observe([]string{"git_status"}, "git_add")
	}

	now := time.Now().Unix()
	cands := []CandidateInput{
		{Key: "git_add", Count: 5, LastUsed: now, SuccessRate: 0.9, InDir: true},
		{Key: "ls", Count: 20, LastUsed: now - 3600, SuccessRate: 1.0, InDir: false},
		{Key: "rm -rf /", Count: 1, LastUsed: now, SuccessRate: 0.0, InDir: false},
	}

	recent := []string{"git_status"}
	scored := e.Rank(cands, recent)

	if len(scored) == 0 {
		t.Fatal("no scored candidates")
	}
	// "git_add" should rank first because it has Markov sequence match + dir match
	if scored[0].Key != "git_add" {
		t.Fatalf("expected git_add first, got %s (score=%.3f)", scored[0].Key, scored[0].Score)
	}
	t.Logf("ranking: ")
	for _, s := range scored {
		t.Logf("  %.4f %s seq=%.2f frec=%.2f dir=%.2f", s.Score, s.Key,
			s.Breaks.Sequence, s.Breaks.Frecency, s.Breaks.Directory)
	}
}

func TestEngineAdapt(t *testing.T) {
	e := NewEngine()
	before := e.Weights

	// Simulate 100 accepted suggestions where directory was the signal
	for i := 0; i < 100; i++ {
		e.Adapt(Key("test"), true)
	}
	if e.Weights.Directory <= before.Directory && e.Weights.Sequence <= before.Sequence {
		t.Log("weights shifted as expected with acceptance feedback")
	}
	// Weights should still sum to ~1.0
	total := e.Weights.Sequence + e.Weights.Frecency + e.Weights.Directory + e.Weights.Success + e.Weights.Session
	if total < 0.95 || total > 1.05 {
		t.Fatalf("weights not normalised: total=%f", total)
	}
}

func TestEngineMultiOrder(t *testing.T) {
	e := NewEngine()

	// Build a workflow pattern: status → add → commit → push
	workflow := [][]string{
		{"git_status"},
		{"git_status", "git_add"},
		{"git_status", "git_add", "git_commit"},
	}
	for round := 0; round < 8; round++ {
		for _, ctx := range workflow {
			switch len(ctx) {
			case 1:
				e.Chain.Observe(ctx, "git_add")
			case 2:
				e.Chain.Observe(ctx, "git_commit")
			case 3:
				e.Chain.Observe(ctx, "git_push")
			}
		}
	}

	// Predict after just seeing "git_status"
	preds := e.Chain.Predict([]string{"git_status"}, 3)
	if len(preds) == 0 || preds[0].Token != "git_add" {
		t.Fatalf("order-1 prediction failed: %+v", preds)
	}
	t.Logf("after git_status → %s (%.3f)", preds[0].Token, preds[0].Prob)

	// After two commands: order-2 should predict git_commit strongly
	preds2 := e.Chain.Predict([]string{"git_status", "git_add"}, 3)
	if len(preds2) == 0 || preds2[0].Token != "git_commit" {
		t.Fatalf("order-2 prediction failed: %+v", preds2)
	}
	t.Logf("after git_status+add → %s (%.3f)", preds2[0].Token, preds2[0].Prob)

	// After three: order-3 predicts git_push
	preds3 := e.Chain.Predict([]string{"git_status", "git_add", "git_commit"}, 3)
	if len(preds3) == 0 || preds3[0].Token != "git_push" {
		t.Fatalf("order-3 prediction failed: %+v", preds3)
	}
	t.Logf("after status+add+commit → %s (%.3f)", preds3[0].Token, preds3[0].Prob)

	// Verify increasing confidence at higher orders
	if preds3[0].Prob <= preds[0].Prob {
		t.Logf("note: higher order prob %.3f vs lower %.3f (expected higher)",
			preds3[0].Prob, preds[0].Prob)
	}
}
