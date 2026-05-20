// Proof test for roadmap §18.2 T-PRIV-002 — Traffic analysis mitigation.
//
// Verifies:
//  1. PadToNearest256 correctly rounds up to the next 256-byte boundary.
//  2. JitteredWakeDelay returns a value within the expected ±50 ms jitter window.
package privacy_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/privacy"
)

func TestPadToNearest256(t *testing.T) {
	tests := []struct {
		input int
		want  int
		label string
	}{
		{0, 256, "zero → first block"},
		{1, 256, "1 → first block"},
		{255, 256, "255 → first block"},
		{256, 256, "256 (exact) → same"},
		{257, 512, "257 → second block"},
		{512, 512, "512 (exact) → same"},
		{513, 768, "513 → third block"},
		{1000, 1024, "1000 → next 256 boundary"},
		{1024, 1024, "1024 (exact) → same"},
		{1025, 1280, "1025 → next block"},
		{-1, 256, "negative → first block"},
	}

	for _, tc := range tests {
		got := privacy.PadToNearest256(tc.input)
		if got != tc.want {
			t.Errorf("PadToNearest256(%d) = %d, want %d (%s)",
				tc.input, got, tc.want, tc.label)
		}
		if got%256 != 0 {
			t.Errorf("PadToNearest256(%d) = %d is not a multiple of 256 (%s)",
				tc.input, got, tc.label)
		}
	}
}

func TestPadToNearest256NeverShrinks(t *testing.T) {
	for n := 0; n <= 1024; n++ {
		got := privacy.PadToNearest256(n)
		if n > 0 && got < n {
			t.Errorf("PadToNearest256(%d) = %d shrank the payload", n, got)
		}
	}
}

func TestJitteredWakeDelay_WithinBounds(t *testing.T) {
	const base = 500 * time.Millisecond
	const jitter = 50 * time.Millisecond
	lo := base - jitter
	hi := base + jitter

	// Run enough iterations to cover the jitter distribution.
	for i := 0; i < 1000; i++ {
		got := privacy.JitteredWakeDelay(base)
		if got < lo || got > hi {
			t.Errorf("JitteredWakeDelay(%v) = %v, want in [%v, %v]",
				base, got, lo, hi)
		}
	}
}

func TestJitteredWakeDelay_Variance(t *testing.T) {
	const base = 500 * time.Millisecond
	seen := make(map[time.Duration]bool)
	for i := 0; i < 200; i++ {
		seen[privacy.JitteredWakeDelay(base)] = true
	}
	// With a ±50 ms jitter and 200 samples we expect well above 10 unique values.
	if len(seen) < 10 {
		t.Errorf("JitteredWakeDelay has insufficient variance: only %d unique values in 200 samples",
			len(seen))
	}
}

func TestJitteredWakeDelay_ZeroBase(t *testing.T) {
	// With base=0 the delay must be ≥ 0 (never negative).
	for i := 0; i < 100; i++ {
		got := privacy.JitteredWakeDelay(0)
		if got < 0 {
			t.Errorf("JitteredWakeDelay(0) = %v, want ≥ 0", got)
		}
	}
}
