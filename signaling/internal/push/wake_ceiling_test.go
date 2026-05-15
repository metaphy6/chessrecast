package push_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/push"
)

// TestWakeCeilingEnforced verifies at most WakeCeiling wakes are allowed per day.
func TestWakeCeilingEnforced(t *testing.T) {
	tracker := push.NewWakeTracker()
	const sender = "alice-pub"
	const recipient = "bob-pub"

	// Fill up to the ceiling.
	for i := 0; i < push.WakeCeiling; i++ {
		if err := tracker.Allow(sender, recipient); err != nil {
			t.Fatalf("unexpected deny at wake %d: %v", i+1, err)
		}
	}
	// One more should be denied.
	if err := tracker.Allow(sender, recipient); err == nil {
		t.Fatal("expected ceiling to deny wake, but got nil error")
	}

	// A different pair should still be allowed.
	if err := tracker.Allow("carol-pub", "dave-pub"); err != nil {
		t.Fatalf("fresh pair should be allowed: %v", err)
	}
}

// TestWakeBackoffAfterIgnored verifies exponential backoff after BackoffThreshold ignored wakes.
func TestWakeBackoffAfterIgnored(t *testing.T) {
	tracker := push.NewWakeTracker()
	const sender = "ping-pub"
	const recipient = "pong-pub"

	// Record BackoffThreshold consecutive ignores.
	for i := 0; i < push.BackoffThreshold; i++ {
		if err := tracker.Allow(sender, recipient); err != nil {
			t.Fatalf("allow before backoff: %v", err)
		}
		tracker.RecordIgnored(sender, recipient)
	}

	// Now further wakes should be blocked by backoff.
	if err := tracker.Allow(sender, recipient); err == nil {
		t.Fatal("expected backoff to deny wake, but got nil error")
	}

	// After recipient responds, backoff should clear.
	tracker.RecordResponded(sender, recipient)
	if err := tracker.Allow(sender, recipient); err != nil {
		t.Fatalf("after response, wake should be allowed: %v", err)
	}
}
