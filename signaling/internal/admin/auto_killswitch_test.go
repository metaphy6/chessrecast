package admin_test

// auto_killswitch_test.go — Roadmap §8.8 / leaf 8.8.b2
//
// Verifies that the AutoKillSwitch:
//   - fires (disables P2P) if no acknowledgement arrives within T_ack.
//   - does NOT fire if an acknowledgement arrives within T_ack.
//   - re-arms after an explicit reset.
//   - calls the registered OnFire callback when it trips.

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/admin"
)

func TestAutoKillSwitch_FiresAfterTimeout(t *testing.T) {
	ks := admin.NewKillSwitch()
	fired := false

	aks := admin.NewAutoKillSwitch(ks, 50*time.Millisecond, func() {
		fired = true
	})
	aks.Arm()
	defer aks.Stop()

	time.Sleep(100 * time.Millisecond)

	if !fired {
		t.Fatal("expected OnFire callback to be called after timeout")
	}
	if !ks.IsDisabled() {
		t.Fatal("expected KillSwitch to be disabled after auto-fire")
	}
}

func TestAutoKillSwitch_DoesNotFireIfAcknowledged(t *testing.T) {
	ks := admin.NewKillSwitch()
	fired := false

	aks := admin.NewAutoKillSwitch(ks, 100*time.Millisecond, func() {
		fired = true
	})
	aks.Arm()
	defer aks.Stop()

	// Acknowledge within the window.
	time.Sleep(20 * time.Millisecond)
	aks.Acknowledge()

	time.Sleep(120 * time.Millisecond)

	if fired {
		t.Fatal("OnFire should NOT have been called after acknowledgement within T_ack")
	}
	if ks.IsDisabled() {
		t.Fatal("KillSwitch should still be enabled after timely acknowledgement")
	}
}

func TestAutoKillSwitch_ReArmsAfterReset(t *testing.T) {
	ks := admin.NewKillSwitch()
	fireCount := 0

	aks := admin.NewAutoKillSwitch(ks, 50*time.Millisecond, func() {
		fireCount++
	})

	// First arm cycle — fires.
	aks.Arm()
	time.Sleep(100 * time.Millisecond)
	if fireCount != 1 {
		t.Fatalf("expected 1 fire after first arm; got %d", fireCount)
	}

	// Reset (re-enable P2P + re-arm).
	ks.Enable()
	aks.Reset()

	// Second arm cycle — fires again.
	time.Sleep(100 * time.Millisecond)
	if fireCount != 2 {
		t.Fatalf("expected 2 fires after second arm; got %d", fireCount)
	}

	aks.Stop()
}
