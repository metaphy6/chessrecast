// T-OPS-001 §9.10 — Dead man's switch policy.
//
// Proof: DeadManSwitchTimeout ≤ 5 minutes, CheckHeartbeat returns Missed when
// elapsed > timeout, OK when within window.
package ops_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/ops"
)

// TestDeadManSwitchTimeoutBound verifies §9.10 T-OPS-001: the alert window
// must not exceed five minutes.
func TestDeadManSwitchTimeoutBound(t *testing.T) {
	const maxAllowed = 5 * time.Minute
	if ops.DeadManSwitchTimeout > maxAllowed {
		t.Errorf("DeadManSwitchTimeout = %v; want ≤ %v (T-OPS-001)",
			ops.DeadManSwitchTimeout, maxAllowed)
	}
}

// TestCheckHeartbeat_OK verifies that a recent heartbeat is accepted.
func TestCheckHeartbeat_OK(t *testing.T) {
	now := int64(1000)
	last := now - 60 // 60 seconds ago — well within 5 min window
	if got := ops.CheckHeartbeat(last, now); got != ops.HeartbeatOK {
		t.Errorf("CheckHeartbeat(%d,%d) = %v; want HeartbeatOK", last, now, got)
	}
}

// TestCheckHeartbeat_Missed verifies that a heartbeat older than the timeout
// is flagged as missed.
func TestCheckHeartbeat_Missed(t *testing.T) {
	now := int64(1000)
	last := now - int64(6*60) // 6 minutes ago — exceeds 5 min window
	if got := ops.CheckHeartbeat(last, now); got != ops.HeartbeatMissed {
		t.Errorf("CheckHeartbeat(%d,%d) = %v; want HeartbeatMissed", last, now, got)
	}
}

// TestCheckHeartbeat_ExactlyAtBoundary verifies boundary condition:
// elapsed == timeout → OK (not yet missed).
func TestCheckHeartbeat_ExactlyAtBoundary(t *testing.T) {
	boundary := int64(ops.DeadManSwitchTimeout / time.Second)
	now := int64(1000)
	last := now - boundary // exactly at boundary
	if got := ops.CheckHeartbeat(last, now); got != ops.HeartbeatOK {
		t.Errorf("CheckHeartbeat at exact boundary = %v; want HeartbeatOK", got)
	}
}

// TestCheckHeartbeat_OneBeyondBoundary verifies that one second beyond the
// boundary is flagged missed.
func TestCheckHeartbeat_OneBeyondBoundary(t *testing.T) {
	boundary := int64(ops.DeadManSwitchTimeout/time.Second) + 1
	now := int64(1000)
	last := now - boundary
	if got := ops.CheckHeartbeat(last, now); got != ops.HeartbeatMissed {
		t.Errorf("CheckHeartbeat one beyond boundary = %v; want HeartbeatMissed", got)
	}
}
