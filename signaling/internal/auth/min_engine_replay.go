// Package auth: min_engine_replay_version enforcement (§12.5.bullet-2).
//
// The signaling server rejects any HELLO carrying an engine_replay_version
// below the operator-configured floor. This is independent of the min_client_version
// check (§3.10) because a forced-update CVE may not require bumping the engine
// version, and an engine version bump may happen without a forced app update.
package auth

import "errors"

// ErrEngineReplayVersionTooOld is returned when the client's engine_replay_version
// is below the operator-configured floor.
//
// Maps to F-PROTO-029 DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED (§10.3).
var ErrEngineReplayVersionTooOld = errors.New(
	"DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED: engine replay version below operator floor",
)

// CheckMinEngineReplayVersion returns ErrEngineReplayVersionTooOld if clientVer
// is strictly less than minVer.
//
// engine_replay_version is a u32 (independent from the semver client version),
// so comparison is a simple unsigned integer comparison.
//
// A minVer of 0 is a no-op floor: all u32 values are ≥ 0.
func CheckMinEngineReplayVersion(clientVer, minVer uint32) error {
	if clientVer < minVer {
		return ErrEngineReplayVersionTooOld
	}
	return nil
}
