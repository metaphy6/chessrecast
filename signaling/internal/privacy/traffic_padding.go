// Package privacy implements signaling-layer privacy mitigations for
// T-PRIV-002: traffic analysis resistance.
//
// Two mechanisms are provided:
//  1. PadToNearest256 — pads a payload byte-count up to the next multiple of
//     256 to prevent size-based request classification.
//  2. JitteredWakeDelay — returns a base long-poll delay with a random ±50 ms
//     jitter to obscure timing fingerprints.
package privacy

import (
	"math/rand/v2"
	"time"
)

const padBlock = 256

// PadToNearest256 returns the smallest multiple of 256 that is ≥ n.
// If n is already a multiple of 256, the same value is returned.
// n must be ≥ 0; negative values are treated as 0.
func PadToNearest256(n int) int {
	if n <= 0 {
		return padBlock
	}
	remainder := n % padBlock
	if remainder == 0 {
		return n
	}
	return n + (padBlock - remainder)
}

// jitterRange is the maximum jitter added or subtracted from a base delay.
const jitterRange = 50 * time.Millisecond

// JitteredWakeDelay returns a duration in [base-jitterRange, base+jitterRange].
// It uses a cryptographically seeded PRNG via math/rand/v2 so the distribution
// is uniform and unpredictable.
func JitteredWakeDelay(base time.Duration) time.Duration {
	// rand.Int64N returns [0, 2*jitterRange) → shift to [-jitterRange, +jitterRange)
	jitter := time.Duration(rand.Int64N(int64(2*jitterRange))) - jitterRange
	d := base + jitter
	if d < 0 {
		return 0
	}
	return d
}
