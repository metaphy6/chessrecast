// host_gone_eviction_test.go — §7.10.6 proof test (roadmap-named file)
package spectator_test

import (
	"fmt"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/spectator"
)

// newManager is a local helper to reduce boilerplate in test sub-files.
func newManager(gameID string, cap int) *spectator.Manager {
	return spectator.NewManager(gameID, cap)
}

// TestHostGoneEviction_RoadmapProof is the primary proof test for §7.10.6.
func TestHostGoneEviction_RoadmapProof(t *testing.T) {
	m := newManager("host_gone_game", 10)
	for i := 0; i < 8; i++ {
		r := m.Admit(fmt.Sprintf("spec%d", i), true)
		if r.ErrCode != "" {
			t.Fatalf("admit spec%d: %s", i, r.ErrCode)
		}
	}

	before := m.SeatedCount()
	count, err := m.HostGoneEviction(10 * time.Second)
	if err != nil {
		t.Fatalf("HostGoneEviction: %v", err)
	}
	if count != before {
		t.Fatalf("evicted %d want %d", count, before)
	}
	if m.SeatedCount() != 0 {
		t.Fatalf("post-eviction seated = %d, want 0", m.SeatedCount())
	}
}

// TestHostGoneEvictionTimeout verifies the 10 s SLA is enforced (§7.10.6).
func TestHostGoneEvictionTimeout(t *testing.T) {
	m := newManager("gone_timeout", 5)
	// Contract: eviction must happen within 10 s.
	start := time.Now()
	_, err := m.HostGoneEviction(10 * time.Second)
	elapsed := time.Since(start)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if elapsed > 10*time.Second {
		t.Fatalf("eviction took %v, exceeds 10 s SLA", elapsed)
	}
}
