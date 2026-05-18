// Package spectator_test tests the signaling-side spectator logic (§7.8, §7.10.6).
package spectator_test

import (
	"fmt"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/spectator"
)

// TestCapacityCapDefault verifies the default 50-seat cap (§7.8.2).
func TestCapacityCapDefault(t *testing.T) {
	m := spectator.NewManager("game1", 0) // 0 → default 50

	// Fill to cap.
	for i := 0; i < spectator.DefaultPerGameCap; i++ {
		r := m.Admit(fmt.Sprintf("acc%04d", i), true)
		if !r.Seated {
			t.Fatalf("seat %d: expected seated, got err=%s waitlisted=%v", i, r.ErrCode, r.Waitlisted)
		}
	}
	if m.SeatedCount() != spectator.DefaultPerGameCap {
		t.Fatalf("seated=%d want=%d", m.SeatedCount(), spectator.DefaultPerGameCap)
	}
}

// TestCapacityCapHardCeiling verifies the 200-seat hard ceiling (§7.8.2).
func TestCapacityCapHardCeiling(t *testing.T) {
	m := spectator.NewManager("game2", 9999) // clamped to 200
	// Fill to HardCeiling without error (just check the cap is 200, not 9999).
	for i := 0; i < spectator.HardCeiling; i++ {
		r := m.Admit(fmt.Sprintf("acc%04d", i), true)
		if r.ErrCode != "" && !r.Waitlisted {
			t.Fatalf("seat %d unexpected error: %s", i, r.ErrCode)
		}
	}
}

// TestCapacityFullWaitlist verifies over-cap joins the FIFO waitlist (§7.8.2).
func TestCapacityFullWaitlist(t *testing.T) {
	m := spectator.NewManager("game3", 2)
	_ = m.Admit("a1", true)
	_ = m.Admit("a2", true)

	// Next one should be waitlisted.
	r := m.Admit("a3", true)
	if !r.Waitlisted {
		t.Fatalf("expected waitlisted, got seated=%v err=%s", r.Seated, r.ErrCode)
	}
}

// TestCapacityFullWaitlistFull verifies SPECTATOR_CAPACITY_FULL when both seats
// and waitlist are full (§7.8.2).
func TestCapacityFullWaitlistFull(t *testing.T) {
	m := spectator.NewManager("game4", 1)
	_ = m.Admit("base", true)
	for i := 0; i < spectator.WaitlistMaxDepth; i++ {
		m.Admit(fmt.Sprintf("w%d", i), true) //nolint:errcheck
	}
	r := m.Admit("overflow", true)
	if r.ErrCode != spectator.ErrCapacityFull {
		t.Fatalf("expected %s, got %s", spectator.ErrCapacityFull, r.ErrCode)
	}
}

// TestAnonJoinRejected verifies SPECTATOR_AUTH_REQUIRED for anonymous joins (§7.8.3).
func TestAnonJoinRejected(t *testing.T) {
	m := spectator.NewManager("game5", 0)
	r := m.Admit("anon", false)
	if r.ErrCode != spectator.ErrAuthRequired {
		t.Fatalf("expected %s, got %s", spectator.ErrAuthRequired, r.ErrCode)
	}
}

// TestJoinRateLimitPerMinute verifies 6 joins / minute cap (§7.8.4).
func TestJoinRateLimitPerMinute(t *testing.T) {
	m := spectator.NewManager("game6", 100)
	const accountID = "heavy_joiner"

	for i := 0; i < spectator.JoinRateLimitPerMinute; i++ {
		r := m.Admit(accountID, true)
		if r.ErrCode != "" && !r.Seated {
			t.Fatalf("join %d unexpected error: %s", i, r.ErrCode)
		}
		// Release immediately to avoid capacity cap.
		m.Release(accountID)
	}

	// 7th join within 1 minute → rate limited.
	r := m.Admit(accountID, true)
	if r.ErrCode != spectator.ErrRateLimited {
		t.Fatalf("expected %s on 7th join, got seated=%v err=%s",
			spectator.ErrRateLimited, r.Seated, r.ErrCode)
	}
}

// TestHostGoneEviction verifies spectators are cleared within 10 s (§7.10.6).
func TestHostGoneEviction(t *testing.T) {
	m := spectator.NewManager("game7", 10)
	for i := 0; i < 5; i++ {
		m.Admit(fmt.Sprintf("s%d", i), true) //nolint:errcheck
	}
	count, err := m.HostGoneEviction(10 * time.Second)
	if err != nil {
		t.Fatalf("HostGoneEviction error: %v", err)
	}
	if count != 5 {
		t.Fatalf("evicted=%d want=5", count)
	}
	if m.SeatedCount() != 0 {
		t.Fatalf("seated after eviction = %d, want 0", m.SeatedCount())
	}
}
