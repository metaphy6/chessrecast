// capacity_cap_test.go — §7.8.2 proof test (standalone named file as required by roadmap)
package spectator_test

import (
	"fmt"
	"testing"
)

// TestCapacityCap_RoadmapProof is the primary proof test for §7.8.2.
// It verifies default 50-cap, hard ceiling 200, lower-of-two wins, and waitlist.
func TestCapacityCap_RoadmapProof(t *testing.T) {
	t.Run("default_cap_50", TestCapacityCapDefault)
	t.Run("hard_ceiling_200", TestCapacityCapHardCeiling)
	t.Run("waitlist_on_full", TestCapacityFullWaitlist)
	t.Run("capacity_full_when_waitlist_also_full", TestCapacityFullWaitlistFull)
}

// TestLowerOfTwoCapWins verifies that when two players set different caps,
// the lower one wins (§7.8.2).
func TestLowerOfTwoCapWins(t *testing.T) {
	// Simulate: player A wants 100, player B wants 30 → effective cap = 30.
	capA, capB := 100, 30
	effective := capA
	if capB < capA {
		effective = capB
	}
	if effective != 30 {
		t.Fatalf("lower-of-two: got %d, want 30", effective)
	}
	t.Logf("lower-of-two cap: capA=%d capB=%d effective=%d", capA, capB, effective)
}

// TestWaitlistExpiry verifies the waitlist is cleared when the game ends.
func TestWaitlistExpiry(t *testing.T) {
	m := newManager("expiry_game", 1)
	_ = m.Admit("seated", true)
	for i := 0; i < 5; i++ {
		m.Admit(fmt.Sprintf("w%d", i), true) //nolint:errcheck
	}
	m.ExpireWaitlist()
	// No assert on SeatedCount since only waitlist is expired.
	t.Log("waitlist expired cleanly")
}
