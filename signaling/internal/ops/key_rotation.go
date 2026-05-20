// Package ops — key rotation overdue detection (§16.2.1).
//
// CheckKeyRotationOverdue returns true when a key's rotation deadline has
// passed, meaning the operator dashboard must display KEY_ROTATION_OVERDUE
// within KeyRotationOverdueWindow of the missed deadline.
package ops

import "time"

// KeyRotationOverdueWindow is the maximum delay between a missed rotation
// deadline and the KEY_ROTATION_OVERDUE alert appearing on the operator
// dashboard. §16.2.1 requires this to be ≤ 24 h.
const KeyRotationOverdueWindow = 24 * time.Hour

// CheckKeyRotationOverdue returns true if the key is overdue for rotation.
//
//   - lastRotated: timestamp of the most recent rotation
//   - interval:    scheduled rotation cadence
//   - now:         current time
//
// A key is overdue when (now - lastRotated) > interval, i.e. the next
// scheduled rotation deadline has passed.
func CheckKeyRotationOverdue(lastRotated time.Time, interval time.Duration, now time.Time) bool {
	return now.Sub(lastRotated) > interval
}
