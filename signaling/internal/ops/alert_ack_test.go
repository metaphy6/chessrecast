// §16.7.2 — Dead-man-switch (T-OPS-001): unacknowledged critical alerts > 72 h
// must trigger OPERATOR_ON_CALL_UNREACHABLE and auto-engage the kill-switch.
//
// Proof: AlertAckTimeout = 72 h; CheckAlertAck returns Unreachable when the
// acknowledgement window is exceeded.
package ops_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/ops"
)

// TestAlertAckTimeoutBound verifies that the alert-acknowledgement window is
// exactly 72 hours (§16.7.2 T-OPS-001).
func TestAlertAckTimeoutBound(t *testing.T) {
	const required = 72 * time.Hour
	if ops.AlertAckTimeout != required {
		t.Errorf("AlertAckTimeout = %v; want exactly %v (§16.7.2)",
			ops.AlertAckTimeout, required)
	}
}

// TestCheckAlertAck_RecentAck verifies that a recently acknowledged alert
// does not trigger OPERATOR_ON_CALL_UNREACHABLE.
func TestCheckAlertAck_RecentAck(t *testing.T) {
	now := time.Now()
	lastAck := now.Add(-1 * time.Hour) // acknowledged 1 hour ago
	result := ops.CheckAlertAck(lastAck, now)
	if result != ops.AlertAckOK {
		t.Errorf("CheckAlertAck 1h ago = %v; want AlertAckOK", result)
	}
}

// TestCheckAlertAck_Exceeded verifies that an unacknowledged alert older than
// 72 h returns AlertAckUnreachable (§16.7.2).
func TestCheckAlertAck_Exceeded(t *testing.T) {
	now := time.Now()
	lastAck := now.Add(-73 * time.Hour) // 73 hours — exceeds 72 h window
	result := ops.CheckAlertAck(lastAck, now)
	if result != ops.AlertAckUnreachable {
		t.Errorf("CheckAlertAck 73h ago = %v; want AlertAckUnreachable", result)
	}
}

// TestCheckAlertAck_ExactBoundary verifies boundary condition:
// at exactly 72 h the alert is still within the window (non-strict).
func TestCheckAlertAck_ExactBoundary(t *testing.T) {
	now := time.Now()
	lastAck := now.Add(-72 * time.Hour)
	result := ops.CheckAlertAck(lastAck, now)
	if result != ops.AlertAckOK {
		t.Errorf("CheckAlertAck at exactly 72h = %v; want AlertAckOK (boundary inclusive)", result)
	}
}
