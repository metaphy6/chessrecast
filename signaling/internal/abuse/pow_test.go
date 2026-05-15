package abuse_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/abuse"
)

// TestPoWRoundTrip verifies that Solve produces a valid solution for a given challenge.
func TestPoWRoundTrip(t *testing.T) {
	p := abuse.DefaultParams()
	challenge, err := abuse.NewChallenge(p)
	if err != nil {
		t.Fatalf("new challenge: %v", err)
	}
	solution, err := abuse.Solve(challenge)
	if err != nil {
		t.Fatalf("solve: %v", err)
	}
	if err := abuse.Verify(challenge, solution); err != nil {
		t.Fatalf("verify: %v", err)
	}
}

// TestPoWRejectsWrongSolution verifies Verify rejects an invalid solution.
func TestPoWRejectsWrongSolution(t *testing.T) {
	p := abuse.DefaultParams()
	challenge, err := abuse.NewChallenge(p)
	if err != nil {
		t.Fatalf("new challenge: %v", err)
	}
	if err := abuse.Verify(challenge, "badbadbadbad"); err == nil {
		t.Fatal("expected invalid solution to be rejected")
	}
}

// TestPoWUniqueChallenge verifies that two challenges have distinct nonces.
func TestPoWUniqueChallenge(t *testing.T) {
	p := abuse.DefaultParams()
	c1, _ := abuse.NewChallenge(p)
	c2, _ := abuse.NewChallenge(p)
	if c1.Nonce == c2.Nonce {
		t.Fatal("two challenges must have distinct nonces")
	}
}
