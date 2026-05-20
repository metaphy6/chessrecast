// §16.1.3 — Forced-update path drilled: signaling enforces min_client_version;
// clients below the floor receive CVE_REQUIRES_FORCED_UPDATE (HTTP 426).
//
// Proof: EnforceMinVersion correctly blocks outdated clients and allows
// up-to-date clients.
package cve_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/cve"
)

// TestForcedUpdateBlocksOldClient verifies that a client below the minimum
// version set by a CVE advisory is blocked (§16.1.3).
func TestForcedUpdateBlocksOldClient(t *testing.T) {
	q, _ := cve.OpenQueue(t.TempDir() + "/q.json")

	// Add an advisory that requires v1.2.0 minimum.
	_ = q.Add(cve.Entry{
		ID:               "GHSA-forced-test",
		Package:          "libsodium",
		Severity:         cve.SeverityCritical,
		Description:      "test forced-update CVE",
		DiscoveredAt:     time.Now().Add(-24 * time.Hour),
		MinClientVersion: "1.2.0",
	})

	// A client on v1.1.0 should be blocked.
	allowed, entry := q.EnforceMinVersion("1.1.0")
	if allowed {
		t.Fatal("client on v1.1.0 should be blocked when min_client_version=1.2.0")
	}
	if entry == nil {
		t.Fatal("blocking entry must be returned")
	}
	if entry.MinClientVersion != "1.2.0" {
		t.Errorf("expected MinClientVersion=1.2.0, got %q", entry.MinClientVersion)
	}
}

// TestForcedUpdateAllowsCurrentClient verifies that a client meeting the
// minimum version requirement is allowed through (§16.1.3).
func TestForcedUpdateAllowsCurrentClient(t *testing.T) {
	q, _ := cve.OpenQueue(t.TempDir() + "/q.json")

	_ = q.Add(cve.Entry{
		ID:               "GHSA-forced-test2",
		Package:          "libsodium",
		Severity:         cve.SeverityCritical,
		Description:      "test forced-update CVE",
		DiscoveredAt:     time.Now().Add(-24 * time.Hour),
		MinClientVersion: "1.2.0",
	})

	// A client exactly at v1.2.0 should be allowed.
	allowed, _ := q.EnforceMinVersion("1.2.0")
	if !allowed {
		t.Fatal("client on v1.2.0 should be allowed when min_client_version=1.2.0")
	}
}

// TestForcedUpdateAllowsNewerClient verifies that a client above the minimum
// is always allowed (§16.1.3).
func TestForcedUpdateAllowsNewerClient(t *testing.T) {
	q, _ := cve.OpenQueue(t.TempDir() + "/q.json")

	_ = q.Add(cve.Entry{
		ID:               "GHSA-forced-test3",
		Package:          "libsodium",
		Severity:         cve.SeverityCritical,
		Description:      "test forced-update CVE",
		DiscoveredAt:     time.Now().Add(-24 * time.Hour),
		MinClientVersion: "1.2.0",
	})

	allowed, _ := q.EnforceMinVersion("2.0.0")
	if !allowed {
		t.Fatal("client on v2.0.0 should be allowed when min_client_version=1.2.0")
	}
}

// TestForcedUpdateAllowsWhenNoAdvisory verifies that all clients are allowed
// when no CVE has a min_client_version set (§16.1.3).
func TestForcedUpdateAllowsWhenNoAdvisory(t *testing.T) {
	q, _ := cve.OpenQueue(t.TempDir() + "/q.json")

	// CVE without MinClientVersion — no forced-update required.
	_ = q.Add(cve.Entry{
		ID:           "GHSA-no-forced",
		Package:      "golang.org/x/crypto",
		Severity:     cve.SeverityHigh,
		Description:  "no forced-update version",
		DiscoveredAt: time.Now().Add(-24 * time.Hour),
	})

	allowed, _ := q.EnforceMinVersion("0.9.0")
	if !allowed {
		t.Fatal("client should be allowed when no advisory sets min_client_version")
	}
}
