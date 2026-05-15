package ratelimit_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/ratelimit"
)

// TestIPRateLimiter verifies per-IP token bucket: burst 30, refill 10/min.
func TestIPRateLimiter(t *testing.T) {
	// refill=10/min, burst=30
	l := ratelimit.NewLimiter(10, 30)

	// Should allow up to 30 requests immediately (burst capacity).
	allowed := 0
	for i := 0; i < 50; i++ {
		if l.Allow("192.168.1.1") {
			allowed++
		}
	}
	if allowed != 30 {
		t.Fatalf("expected burst of 30, got %d allowed", allowed)
	}

	// Different IPs are independent.
	if !l.Allow("10.0.0.1") {
		t.Fatal("fresh IP should be allowed")
	}
}

// TestIPRateLimiterDistinctIPs verifies different IPs have independent buckets.
func TestIPRateLimiterDistinctIPs(t *testing.T) {
	l := ratelimit.NewLimiter(10, 30)

	// Exhaust IP1.
	for i := 0; i < 30; i++ {
		l.Allow("1.2.3.4")
	}
	if l.Allow("1.2.3.4") {
		t.Fatal("exhausted IP should be denied")
	}
	// IP2 should still be fresh.
	if !l.Allow("5.6.7.8") {
		t.Fatal("fresh IP should be allowed")
	}
}
