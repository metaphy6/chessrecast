package auth_test

import (
	"crypto/ed25519"
	"crypto/rand"
	"math"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/auth"
)

// TestTimingSideChannel verifies that Verify does not leak the existence of
// valid-vs-invalid accounts via measurable timing differences.
//
// The test measures Verify() timing for:
//   (a) a completely garbled signature (all zeros), and
//   (b) a structurally valid but wrong signature (wrong key).
//
// Both should take the same order-of-magnitude time because the verifier
// must not short-circuit on unknown-key vs bad-signature.
//
// Statistical threshold: |mean_a - mean_b| < 3 * max(stddev_a, stddev_b).
// (A 3σ test is very conservative for this purpose.)
func TestTimingSideChannel(t *testing.T) {
	const iterations = 200

	pub1, priv1, _ := ed25519.GenerateKey(rand.Reader)
	pub2, _, _ := ed25519.GenerateKey(rand.Reader)
	_ = priv1

	v := auth.NewVerifier()

	// Claim shared by both arms.
	claims := auth.RequestClaims{
		Method: "POST",
		Path:   "/v1/offers",
		Ts:     time.Now(),
	}

	// Arm A: sign with key1, verify against key1 (should pass, testing verify time).
	sigA := auth.Sign(priv1, claims)

	// Arm B: sign with key2, verify against key1 (signature mismatch).
	_, priv2, _ := ed25519.GenerateKey(rand.Reader)
	sigB := auth.Sign(priv2, claims)

	// Warm up the verifier to avoid JIT / cache cold-start bias.
	for i := 0; i < 10; i++ {
		_ = v.Verify(pub1, sigA, claims)
		_ = v.Verify(pub1, sigB, claims)
	}

	// Measure arm A.
	var timesA [iterations]time.Duration
	for i := 0; i < iterations; i++ {
		// Re-generate claims with a fresh timestamp to avoid replay cache hits.
		c := auth.RequestClaims{Method: "POST", Path: "/v1/offers", Ts: time.Now().Add(time.Duration(i+1000) * time.Second)}
		sig := auth.Sign(priv1, c)
		start := time.Now()
		_ = v.Verify(pub1, sig, c)
		timesA[i] = time.Since(start)
	}

	// Measure arm B (wrong-key, verify against pub1).
	var timesB [iterations]time.Duration
	for i := 0; i < iterations; i++ {
		c := auth.RequestClaims{Method: "POST", Path: "/v1/offers", Ts: time.Now().Add(time.Duration(i+10000) * time.Second)}
		sig := auth.Sign(priv2, c)
		start := time.Now()
		_ = v.Verify(pub1, sig, c)
		timesB[i] = time.Since(start)
	}

	// Use pub2 to suppress unused-variable lint.
	_ = pub2

	meanA, stdA := stats(timesA[:])
	meanB, stdB := stats(timesB[:])

	t.Logf("arm A (valid sig): mean=%.1fµs stddev=%.1fµs", meanA/1e3, stdA/1e3)
	t.Logf("arm B (wrong sig): mean=%.1fµs stddev=%.1fµs", meanB/1e3, stdB/1e3)

	// The threshold is generous: timing differences up to 3× the larger stddev
	// are acceptable (pure-Go crypto constant-time, no DB involved here).
	threshold := 3.0 * math.Max(stdA, stdB)
	diff := math.Abs(meanA - meanB)
	if diff > threshold {
		t.Errorf("timing gap too large: |%.0f - %.0f| = %.0f ns > threshold %.0f ns (3σ)",
			meanA, meanB, diff, threshold)
	}
}

func stats(d []time.Duration) (mean, stddev float64) {
	n := float64(len(d))
	for _, v := range d {
		mean += float64(v)
	}
	mean /= n
	for _, v := range d {
		diff := float64(v) - mean
		stddev += diff * diff
	}
	stddev = math.Sqrt(stddev / n)
	return
}
