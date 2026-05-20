// §16.2.1 — KEY_ROTATION_OVERDUE alert fires within 24 h of a rotation deadline.
//
// Proof: KeyRotationOverdueWindow ≤ 24 h, CheckKeyRotationOverdue returns
// Overdue when the deadline has passed by more than the window.
package ops_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/ops"
)

// TestKeyRotationOverdueWindowBound verifies that the alert window is at most
// 24 hours, as required by §16.2.1.
func TestKeyRotationOverdueWindowBound(t *testing.T) {
	const maxWindow = 24 * time.Hour
	if ops.KeyRotationOverdueWindow > maxWindow {
		t.Errorf("KeyRotationOverdueWindow = %v; want ≤ %v (§16.2.1)",
			ops.KeyRotationOverdueWindow, maxWindow)
	}
}

// TestKeyRotationNotOverdue verifies that a key rotated before its deadline
// is not flagged.
func TestKeyRotationNotOverdue(t *testing.T) {
	now := time.Now()
	// Rotated 80 days ago, interval is 90 days → still within schedule.
	lastRotated := now.Add(-80 * 24 * time.Hour)
	interval := 90 * 24 * time.Hour

	if ops.CheckKeyRotationOverdue(lastRotated, interval, now) {
		t.Error("key rotated 80 days ago with 90-day interval should not be overdue")
	}
}

// TestKeyRotationOverdue verifies that a key past its rotation deadline
// is flagged within KeyRotationOverdueWindow (§16.2.1).
func TestKeyRotationOverdue(t *testing.T) {
	now := time.Now()
	// Rotated 91 days ago, interval is 90 days → overdue.
	lastRotated := now.Add(-91 * 24 * time.Hour)
	interval := 90 * 24 * time.Hour

	if !ops.CheckKeyRotationOverdue(lastRotated, interval, now) {
		t.Error("key rotated 91 days ago with 90-day interval must be flagged overdue")
	}
}

// TestKeyRotationExactlyAtDeadline verifies boundary: at exactly the deadline
// the key is not yet overdue (strict >).
func TestKeyRotationExactlyAtDeadline(t *testing.T) {
	now := time.Now()
	lastRotated := now.Add(-90 * 24 * time.Hour) // exactly at deadline
	interval := 90 * 24 * time.Hour

	if ops.CheckKeyRotationOverdue(lastRotated, interval, now) {
		t.Error("key at exactly the deadline must not be flagged as overdue")
	}
}
