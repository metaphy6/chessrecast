package ratelimit_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/ratelimit"
)

// TestAccountRateLimiter verifies per-account token bucket: burst 120, refill 60/min.
func TestAccountRateLimiter(t *testing.T) {
	// refill=60/min (1/s), burst=120
	l := ratelimit.NewLimiter(60, 120)

	allowed := 0
	for i := 0; i < 200; i++ {
		if l.Allow("account-pub-abc") {
			allowed++
		}
	}
	if allowed != 120 {
		t.Fatalf("expected burst of 120, got %d allowed", allowed)
	}
}

// TestAccountRateLimiterDistinctAccounts verifies independent buckets per account.
func TestAccountRateLimiterDistinctAccounts(t *testing.T) {
	l := ratelimit.NewLimiter(60, 120)

	for i := 0; i < 120; i++ {
		l.Allow("acct-A")
	}
	if l.Allow("acct-A") {
		t.Fatal("exhausted account should be denied")
	}
	if !l.Allow("acct-B") {
		t.Fatal("fresh account should be allowed")
	}
}
