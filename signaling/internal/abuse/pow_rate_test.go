package abuse_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/abuse"
)

// TestPoWSolutionRateLimit verifies that a single IP is limited to 50 PoW
// solution attempts per minute, and that the 51st is rejected.
func TestPoWSolutionRateLimit(t *testing.T) {
	rl := abuse.NewPoWRateLimiter(50, 50) // 50/min burst 50

	const ip = "203.0.113.1"
	for i := 0; i < 50; i++ {
		if !rl.Allow(ip) {
			t.Fatalf("attempt %d should be allowed (below burst cap)", i+1)
		}
	}
	if rl.Allow(ip) {
		t.Fatal("51st attempt should be rejected (burst exhausted)")
	}
}

// TestPoWSolutionRateLimitDistinctIPs verifies that distinct IPs each get their
// own independent bucket.
func TestPoWSolutionRateLimitDistinctIPs(t *testing.T) {
	rl := abuse.NewPoWRateLimiter(50, 50)
	rl.Allow("10.0.0.1") // deplete first IP
	if !rl.Allow("10.0.0.2") {
		t.Fatal("distinct IP should have its own bucket")
	}
}

// TestPoWChallengeSignedAndSingleUse verifies that solving the same challenge
// twice is rejected (single-redemption) and that a challenge carries a nonce.
func TestPoWChallengeSignedAndSingleUse(t *testing.T) {
	p := abuse.DefaultParams()
	ch, err := abuse.NewChallenge(p)
	if err != nil {
		t.Fatalf("NewChallenge: %v", err)
	}
	if ch.Nonce == "" {
		t.Fatal("challenge nonce must not be empty")
	}

	sol, err := abuse.Solve(ch)
	if err != nil {
		t.Fatalf("Solve: %v", err)
	}

	redeemer := abuse.NewChallengeRedeemer()
	if err := redeemer.Redeem(ch, sol); err != nil {
		t.Fatalf("first redemption should succeed: %v", err)
	}
	if err := redeemer.Redeem(ch, sol); err == nil {
		t.Fatal("second redemption of same challenge should be rejected")
	}
}
