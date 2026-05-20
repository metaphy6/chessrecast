// §16.5.1-16.5.3 — Deprecation ladder: soft-deprecate → hard-deprecate
// sunset windows for wire_version, crypto_suite_id, engine_replay_version.
//
// §16.5.4 — Sunset events documented at docs/P2P_DEPRECATIONS.md.
//
// Proof: deprecation constants encode the minimum sunset windows.
package cve_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/cve"
)

// TestSunsetWindowWireVersion verifies the wire_version / crypto_suite_id
// sunset window is at least 90 days (§16.5.3).
func TestSunsetWindowWireVersion(t *testing.T) {
	const minWindow = 90 * 24 * time.Hour
	if cve.SunsetWindowWireVersion < minWindow {
		t.Errorf("SunsetWindowWireVersion = %v; want ≥ %v (§16.5.3)",
			cve.SunsetWindowWireVersion, minWindow)
	}
}

// TestSunsetWindowEngineReplay verifies the engine_replay_version sunset
// window is at least 30 days (§16.5.3).
func TestSunsetWindowEngineReplay(t *testing.T) {
	const minWindow = 30 * 24 * time.Hour
	if cve.SunsetWindowEngineReplay < minWindow {
		t.Errorf("SunsetWindowEngineReplay = %v; want ≥ %v (§16.5.3)",
			cve.SunsetWindowEngineReplay, minWindow)
	}
}

// TestDeprecationCodesPresent verifies that the hard-deprecation error codes
// are declared (§16.5.2).
func TestDeprecationCodesPresent(t *testing.T) {
	codes := []string{
		cve.CodeDeprecatedWireVersionRejected,
		cve.CodeDeprecatedCryptoSuiteRejected,
		cve.CodeDeprecatedEngineReplayVersionRejected,
	}
	for _, c := range codes {
		if c == "" {
			t.Errorf("deprecation error code must not be empty (§16.5.2)")
		}
	}
}
