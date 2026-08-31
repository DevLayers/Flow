package brain

import (
	"testing"
)

func TestChainObserveAndPredict(t *testing.T) {
	c := NewChain(3)

	// Simulate a DevOps workflow:
	// git status → git add → git commit → kubectl apply
	seq := []string{"git_status", "git_add", "git_commit", "kubectl_apply"}

	// Observe transitions at all orders
	for i := 0; i < len(seq)-1; i++ {
		context := seq[max(0, i-2):i+1] // last 3 skeletons as context
		c.Observe(context[:len(context)-1], seq[i+1])
	}

	// Repeat the pattern to build confidence
	for i := 0; i < 5; i++ {
		c.Observe([]string{"git_status"}, "git_add")
		c.Observe([]string{"git_status", "git_add"}, "git_commit")
		c.Observe([]string{"git_add"}, "git_commit")
	}

	// Predict after "git status"
	preds := c.Predict([]string{"git_status"}, 3)
	if len(preds) == 0 {
		t.Fatal("expected predictions for git_status context")
	}
	if preds[0].Token != "git_add" && preds[0].Token != "git_commit" {
		t.Fatalf("unexpected top prediction: %+v", preds[0])
	}
	t.Logf("after git_status: %s (prob=%.3f)", preds[0].Token, preds[0].Prob)
}

func TestChainBackoff(t *testing.T) {
	c := NewChain(3)

	// Only observe order-1 transitions
	c.Observe([]string{"docker"}, "docker_ps")
	c.Observe([]string{"docker"}, "docker_images")

	// Query with deep context — should back off to order-1
	preds := c.Predict([]string{"a", "b", "docker"}, 5)
	if len(preds) == 0 {
		t.Fatal("backoff failed: no predictions")
	}
	found := false
	for _, p := range preds {
		if p.Token == "docker_ps" || p.Token == "docker_images" {
			found = true
		}
	}
	if !found {
		t.Fatalf("backoff lost known candidates: %+v", preds)
	}
}

func TestChainEmpty(t *testing.T) {
	c := NewChain(3)
	preds := c.Predict([]string{"unknown_cmd"}, 5)
	if len(preds) != 0 {
		t.Fatalf("expected empty predictions for unknown context, got %+v", preds)
	}
}

func TestChainSize(t *testing.T) {
	c := NewChain(3)
	c.Observe([]string{"a"}, "b")
	c.Observe([]string{"c"}, "d")
	s := c.Size()
	if s < 2 {
		t.Fatalf("chain size too small: %d", s)
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
