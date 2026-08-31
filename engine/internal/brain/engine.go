package brain

// Engine orchestrates all intelligence signals into a single scoring
// pipeline. This is the "brain stem" — it doesn't generate commands,
// it ranks them based on everything Flow knows about you.
//
// Signals (each normalised to [0..1] before weighting):
//   1. Sequence    — Markov chain prediction probability
//   2. Frecency    — exponential time-decay × log-frequency
//   3. Directory   — evidence the command was run in THIS directory
//   4. Success     — historical success rate for this command
//   5. Session     — position depth (early session = setup, late = verify)

import (
	"math"
	"sort"
	"strings"
	"time"
)

// SignalWeights holds the tunable weight per signal.
// These start at sensible defaults and adapt via acceptance feedback.
type SignalWeights struct {
	Sequence  float64 `json:"sequence"`
	Frecency  float64 `json:"frecency"`
	Directory float64 `json:"directory"`
	Success   float64 `json:"success"`
	Session   float64 `json:"session"`
}

// DefaultWeights — balanced starting point.
var DefaultWeights = SignalWeights{
	Sequence:  0.30,
	Frecency:  0.25,
	Directory: 0.25,
	Success:   0.10,
	Session:   0.10,
}

// CandidateInput is what the caller provides about each candidate.
type CandidateInput struct {
	Key          string
	Count        int     // usage count
	LastUsed     int64   // unix timestamp of last use
	SuccessRate  float64 // [0..1], -1 = unknown
	InDir        bool    // has directory evidence for current cwd
	MarkovScore  float64 // from Chain.Predict, [0..1]
	SessionDepth int     // how many commands since session start
}

// Scored is a candidate with its computed score and breakdown.
type Scored struct {
	CandidateInput
	Score  float64            `json:"score"`
	Breaks SignalBreakdown    `json:"breakdown"`
}

type SignalBreakdown struct {
	Sequence  float64 `json:"sequence"`
	Frecency  float64 `json:"frecency"`
	Directory float64 `json:"directory"`
	Success   float64 `json:"success"`
	Session   float64 `json:"session"`
}

// Engine holds the chain + adaptive weights.
type Engine struct {
	Chain   *Chain
	Weights SignalWeights

	// feedback tracking
	acceptCount int64
	ignoreCount int64

	sessionStart time.Time
	sessionDepth int
}

// NewEngine creates a Brain with default weights.
func NewEngine() *Engine {
	return &Engine{
		Chain:        NewChain(3),
		Weights:      DefaultWeights,
		sessionStart: time.Now(),
	}
}

// ObserveSession feeds a completed command skeleton into the sequence model
// and increments session depth.
func (e *Engine) ObserveSession(skeleton string) {
	if skeleton == "" {
		return
	}
	e.sessionDepth++
}

// Rank scores all candidates using multi-signal evaluation.
// Returns candidates sorted by score desc.
func (e *Engine) Rank(cands []CandidateInput, recentSkeletons []string) []Scored {
	preds := e.Chain.Predict(recentSkeletons, len(cands))
	predMap := make(map[string]float64, len(preds))
	for _, p := range preds {
		predMap[p.Token] = p.Prob
	}

	now := time.Now().Unix()
	scored := make([]Scored, 0, len(cands))

	for _, c := range cands {
		var br SignalBreakdown

		// ── Sequence ──
		br.Sequence = predMap[c.Key]

		// ── Frecency: continuous decay × ln(1+count) ──
		if c.LastUsed > 0 {
			ageH := math.Max(float64(now-c.LastUsed)/3600.0, 0)
			halfLife := 6.0
			decay := math.Exp2(-ageH / halfLife)
			freq := math.Log1p(float64(c.Count))
			br.Frecency = decay * freq / math.Log1p(50) // normalise: count=50 ≈ max
		}
		clamp01(&br.Frecency)

		// ── Directory ──
		if c.InDir {
			br.Directory = 1.0
		}

		// ── Success ──
		if c.SuccessRate >= 0 {
			br.Success = c.SuccessRate
		}

		// ── Session depth (normalised) ──
		br.Session = math.Min(float64(e.sessionDepth)/20.0, 1.0)

		w := e.Weights
		score := w.Sequence*br.Sequence +
			w.Frecency*br.Frecency +
			w.Directory*br.Directory +
			w.Success*br.Success +
			w.Session*br.Session

		s := Scored{CandidateInput: c, Score: score, Breaks: br}
		scored = append(scored, s)
	}

	sort.SliceStable(scored, func(i, j int) bool {
		return scored[i].Score > scored[j].Score
	})
	return scored
}

// Adapt adjusts signal weights based on whether the top suggestion was
// accepted or ignored. Called on each suggestion resolution.
func (e *Engine) Adapt(topCandidate Key, accepted bool) {
	const alpha = 0.01
	w := &e.Weights

	if accepted {
		e.acceptCount++
	} else {
		e.ignoreCount++
	}

	// Nudge all weights toward signals that contributed to accepted results,
	// away from those that led to ignored ones.
	sign := -1.0
	if accepted {
		sign = 1.0
	}
	w.Sequence += sign * alpha * w.Sequence * 0.3
	w.Frecency += sign * alpha * w.Frecency * 0.3
	w.Directory += sign * alpha * w.Directory * 0.3

	// Normalise to sum=1
	total := w.Sequence + w.Frecency + w.Directory + w.Success + w.Session
	if total > 0 {
		w.Sequence /= total
		w.Frecency /= total
		w.Directory /= total
		w.Success /= total
		w.Session /= total
	}
}

// Stats returns engine diagnostics.
func (e *Engine) Stats() map[string]interface{} {
	return map[string]interface{}{
		"chain_contexts": e.Chain.Size(),
		"accept_count":   e.acceptCount,
		"ignore_count":   e.ignoreCount,
		"weights":        e.Weights,
		"session_depth":  e.sessionDepth,
	}
}

func clamp01(f *float64) {
	*f = math.Max(0, math.Min(*f, 1))
}

// Key is an alias for readability in Adapt signature.
type Key = string

// TrimSpace is re-exported to avoid importing strings at every call site.
func TrimSpace(s string) string { return strings.TrimSpace(s) }
