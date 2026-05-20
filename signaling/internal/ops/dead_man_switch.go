// Package ops provides operational safety policies for the signaling server.
//
// §9.10 T-OPS-001 — Dead man's switch: if no heartbeat is received within
// DeadManSwitchTimeout, the server must alert before continuing to serve
// requests so that silent failures do not go undetected.
//
// §16.7.2 T-OPS-001 (Phase 16 extension) — Alert acknowledgement: if a
// critical alert goes unacknowledged for more than AlertAckTimeout (72 h),
// OPERATOR_ON_CALL_UNREACHABLE is raised and the kill-switch auto-engages.
//
// §16.8.5 Integrity — all rotation events are signed by the predecessor key
// so that an attacker who steals a key cannot silently rotate without an
// audit trail.
package ops

import "time"

// DeadManSwitchTimeout is the maximum interval between heartbeats before an
// alert is raised.  §9.10 T-OPS-001 requires this to be ≤ 5 minutes.
const DeadManSwitchTimeout = 5 * time.Minute

// AlertAckTimeout is the maximum time a critical alert may go unacknowledged
// before OPERATOR_ON_CALL_UNREACHABLE is raised and the §6.3 kill-switch
// auto-engages (§16.7.2 T-OPS-001).
const AlertAckTimeout = 72 * time.Hour

// RotationEventSigningEnabled declares that all key-rotation events must be
// signed by the predecessor key, ensuring an attacker who steals a key cannot
// rotate it without leaving an audit trail (§16.8.5).
const RotationEventSigningEnabled = true

// HeartbeatResult describes the outcome of a heartbeat check.
type HeartbeatResult int

const (
	// HeartbeatOK means the heartbeat was received within the timeout window.
	HeartbeatOK HeartbeatResult = iota
	// HeartbeatMissed means no heartbeat was received within DeadManSwitchTimeout.
	HeartbeatMissed
)

// CheckHeartbeat evaluates whether [lastHeartbeat] is within
// DeadManSwitchTimeout of [now].
func CheckHeartbeat(lastHeartbeat, now int64) HeartbeatResult {
	elapsed := time.Duration(now-lastHeartbeat) * time.Second
	if elapsed > DeadManSwitchTimeout {
		return HeartbeatMissed
	}
	return HeartbeatOK
}

// AlertAckResult describes the outcome of an alert-acknowledgement check.
type AlertAckResult int

const (
	// AlertAckOK means the most recent alert was acknowledged within AlertAckTimeout.
	AlertAckOK AlertAckResult = iota
	// AlertAckUnreachable means no acknowledgement was received within
	// AlertAckTimeout; OPERATOR_ON_CALL_UNREACHABLE must be raised and the
	// §6.3 kill-switch auto-engaged (§16.7.2).
	AlertAckUnreachable
)

// CheckAlertAck evaluates whether the operator acknowledged the most recent
// critical alert within AlertAckTimeout of [now].
//
//   - lastAck: time of the most recent operator acknowledgement
//   - now:     current time
func CheckAlertAck(lastAck, now time.Time) AlertAckResult {
	if now.Sub(lastAck) > AlertAckTimeout {
		return AlertAckUnreachable
	}
	return AlertAckOK
}
