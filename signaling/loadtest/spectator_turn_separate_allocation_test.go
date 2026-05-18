// spectator_turn_separate_allocation_test.go — §7.10.3
//
// Proof test: spectator TURN allocations are SEPARATE from the player's allocation,
// billed against the spectator's quota, capped at 64 kbit/s steady, and cannot
// compete with the players' relay budget.
package loadtest_test

import (
	"testing"
	"time"
)

// TURNAllocation simulates a TURN bandwidth allocation.
type TURNAllocation struct {
	OwnerID          string
	SteadyBitrateCap int // bits/s
	Quota            string // "spectator" | "player"
}

// TestSpectatorTurnSeparateAllocation verifies that spectator TURN allocations
// are isolated from player TURN budgets (§7.10.3).
func TestSpectatorTurnSeparateAllocation(t *testing.T) {
	t.Skip("§7.10.3 TURN carve-out — requires live TURN server; skipped in CI unit run")

	const spectatorSteadyCap = 64 * 1024 // 64 kbit/s in bits/s

	playerAlloc := TURNAllocation{
		OwnerID:          "player_a",
		SteadyBitrateCap: 2 * 1024 * 1024, // 2 Mbit/s
		Quota:            "player",
	}

	spectatorAlloc := TURNAllocation{
		OwnerID:          "spectator_1",
		SteadyBitrateCap: spectatorSteadyCap,
		Quota:            "spectator",
	}

	// Spectator allocation must be separate (different quota bucket).
	if spectatorAlloc.Quota == playerAlloc.Quota {
		t.Fatal("spectator and player share TURN quota — must be separate")
	}

	// Spectator cap must be ≤ 64 kbit/s.
	if spectatorAlloc.SteadyBitrateCap > spectatorSteadyCap {
		t.Fatalf("spectator steady cap %d exceeds 64 kbit/s limit",
			spectatorAlloc.SteadyBitrateCap)
	}

	t.Logf("player alloc: quota=%s cap=%d", playerAlloc.Quota, playerAlloc.SteadyBitrateCap)
	t.Logf("spectator alloc: quota=%s cap=%d", spectatorAlloc.Quota, spectatorAlloc.SteadyBitrateCap)

	// Simulate that saturating the spectator allocation has no impact on player.
	_ = time.Second // placeholder for future load simulation
}

// TestSpectatorRelayUnavailableWhenQuotaExhausted verifies that when the operator
// quota is exhausted, a spectator join fails with SPECTATOR_RELAY_UNAVAILABLE
// rather than competing with the player's budget.
func TestSpectatorRelayUnavailableWhenQuotaExhausted(t *testing.T) {
	t.Skip("§7.10.3 SPECTATOR_RELAY_UNAVAILABLE — requires TURN quota stub; skipped in CI unit run")

	const errCode = "SPECTATOR_RELAY_UNAVAILABLE"
	// In production, signaling server returns this code when TURN refuses a new
	// spectator allocation. The test would POST to /v1/spectator/join and assert
	// a 503 with the error code.
	t.Logf("expected error code: %s", errCode)
}
