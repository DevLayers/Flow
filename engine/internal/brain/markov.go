// Package brain implements Flow Engine's calculative intelligence.
//
// It learns command sequences using multi-order Markov chains with
// adaptive interpolation — no neural networks, no cloud APIs. Pure
// statistics over your own behavioral data, computed in microseconds.
//
// Core idea: shell commands have strong Markov properties.
//   P(next | all_previous) ≈ P(next | last_n_tokens)
//
// Evidence: "git" is followed by status/commit/push 65% of the time.
//           "cd" is followed by .. or project names 80% of the time.
package brain

import (
	"fmt"
	"strings"
	"sync"
)

// Chain is a multi-order Markov chain over command skeletons.
// Orders 1–3 are tracked simultaneously with interpolated backoff.
type Chain struct {
	mu sync.RWMutex

	// orders[n] maps context-key → next-skeleton → observation count.
	// Context key for order N = last N skeletons joined by \x1f.
	// Order 1 context = "" (unigram baseline).
	orders map[int]map[string]map[string]int

	// maxOrder caps lookback depth.
	maxOrder int

	// smoothing constant: higher = trust lower orders more when sparse.
	smoothingK float64

	// total observations per order (for probability normalisation)
	totals map[int]int
}

const (
	sep       = "\x1f" // unit separator between skeleton tokens
	maxOrderN = 3
	smoothK   = 2.0
)

// NewChain creates a Markov chain tracking orders 1 through maxOrder.
func NewChain(maxOrder int) *Chain {
	if maxOrder < 1 || maxOrder > 6 {
		maxOrder = maxOrderN
	}
	c := &Chain{
		orders:     make(map[int]map[string]map[string]int),
		maxOrder:   maxOrder,
		smoothingK: smoothK,
		totals:     make(map[int]int),
	}
	for i := 1; i <= c.maxOrder; i++ {
		c.orders[i] = make(map[string]map[string]int)
	}
	return c
}

// Observe records one transition: after seeing `contextTokens`, the next
// skeleton appeared. Updates ALL orders simultaneously.
func (c *Chain) Observe(contextTokens []string, next string) {
	if len(contextTokens) == 0 || next == "" {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()

	for order := 1; order <= c.maxOrder && order <= len(contextTokens); order++ {
		ctx := contextKey(contextTokens, order)
		table := c.orders[order]
		if table[ctx] == nil {
			table[ctx] = make(map[string]int)
		}
		table[ctx][next]++
		c.totals[order]++
	}
}

// contextKey builds the lookup key for a given order depth.
func contextKey(tokens []string, order int) string {
	start := len(tokens) - order
	if start < 0 {
		start = 0
	}
	return strings.Join(tokens[start:], sep)
}

// Prediction is one candidate with its computed probability.
type Prediction struct {
	Token      string  `json:"token"`
	Prob       float64 `json:"prob"`
	Order      int     `json:"order"`      // which order contributed most
	Count      int     `json:"count"`      // raw observation count at best order
	Confidence float64 `json:"confidence"` // λ at best order
}

// Predict returns ranked candidates given the recent skeleton sequence.
// Uses interpolated smoothing across all orders — higher orders dominate
// when they have data, lower orders fill sparse gaps.
func (c *Chain) Predict(recent []string, limit int) []Prediction {
	if len(recent) == 0 {
		return nil
	}
	c.mu.RLock()
	defer c.mu.RUnlock()

	// Accumulate blended probability per candidate.
	blended := make(map[string]*blendedPred)

	for order := 1; order <= c.maxOrder && order <= len(recent); order++ {
		ctx := contextKey(recent, order)
		counts := c.orders[order][ctx]
		total := 0
		for _, count := range counts {
			total += count
		}
		if total == 0 {
			continue
		}

		// Adaptive λ: trust this order proportionally to its evidence volume.
		lambda := float64(total) / (float64(total) + c.smoothingK)

		for token, count := range counts {
			p := lambda * (float64(count) / float64(total))
			bp, ok := blended[token]
			if !ok {
				bp = &blendedPred{bestOrder: order, bestCount: count, bestLambda: lambda}
				blended[token] = bp
			}
			bp.prob += p
			if order > bp.bestOrder || (order == bp.bestOrder && count > bp.bestCount) {
				bp.bestOrder = order
				bp.bestCount = count
				bp.bestLambda = lambda
			}
		}
	}

	// Rank by blended probability desc.
	preds := make([]Prediction, 0, len(blended))
	for token, bp := range blended {
		preds = append(preds, Prediction{
			Token:      token,
			Prob:       bp.prob,
			Order:      bp.bestOrder,
			Count:      bp.bestCount,
			Confidence: bp.bestLambda,
		})
	}
	// insertion sort desc (small n)
	for i := 1; i < len(preds); i++ {
		for j := i; j > 0 && preds[j].Prob > preds[j-1].Prob; j-- {
			preds[j], preds[j-1] = preds[j-1], preds[j]
		}
	}
	if limit > 0 && len(preds) > limit {
		preds = preds[:limit]
	}
	return preds
}

// blendedPred tracks accumulation across orders.
type blendedPred struct {
	prob       float64
	bestOrder  int
	bestCount  int
	bestLambda float64
}

// Export serialises the chain state for persistence.
func (c *Chain) Export() map[string]interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()
	out := make(map[string]interface{})
	out["maxOrder"] = c.maxOrder
	out["totals"] = c.totals
	for order, table := range c.orders {
		key := fmt.Sprintf("order_%d", order)
		inner := make(map[string]interface{})
		for ctx, candidates := range table {
			inner[ctx] = candidates
		}
		out[key] = inner
	}
	return out
}

// Import restores chain state from persisted data.
func (c *Chain) Import(data map[string]interface{}) {
	c.mu.Lock()
	defer c.mu.Unlock()
	for key, val := range data {
		if len(key) > 6 && key[:6] == "order_" {
			var order int
			fmt.Sscanf(key[6:], "%d", &order)
			if inner, ok := val.(map[string]interface{}); ok {
				if c.orders[order] == nil {
					c.orders[order] = make(map[string]map[string]int)
				}
				for ctx, candidates := range inner {
					if cmap, ok := candidates.(map[string]interface{}); ok {
						c.orders[order][ctx] = make(map[string]int)
						for tok, cnt := range cmap {
							if f, ok := cnt.(float64); ok {
								c.orders[order][ctx][tok] = int(f)
							} else if i, ok := cnt.(int); ok {
								c.orders[order][ctx][tok] = i
							}
						}
					}
				}
			}
		}
	}
}

// Size returns the number of distinct contexts across all orders.
func (c *Chain) Size() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	total := 0
	for _, table := range c.orders {
		total += len(table)
	}
	return total
}
