// Package ops provides operational safety policies for the signaling server.
//
// §9.10 T-OPS-001 — Dead man's switch: if no heartbeat is received within
// DeadManSwitchTimeout, the server must alert before continuing to serve
// requests so that silent failures do not go undetected.
package ops

import "time"

// DeadManSwitchTimeout is the maximum interval between heartbeats before an
// alert is raised.  §9.10 T-OPS-001 requires this to be ≤ 5 minutes.
const DeadManSwitchTimeout = 5 * time.Minute

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
