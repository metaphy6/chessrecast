package cve_test

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/cve"
)

// TestSLAPanelNoCritical verifies that UnpatchedCriticalDays returns -1 when
// there are no unpatched critical CVEs — the panel shows "green".
func TestSLAPanelNoCritical(t *testing.T) {
	dir := t.TempDir()
	q, _ := cve.OpenQueue(filepath.Join(dir, "q.json"))

	// Add a patched critical (should not count).
	patched := time.Now().Add(-2 * time.Hour)
	q.Add(cve.Entry{
		ID:           "PATCHED-001",
		Severity:     cve.SeverityCritical,
		DiscoveredAt: time.Now().Add(-10 * 24 * time.Hour),
		PatchedAt:    &patched,
	})

	if d := q.UnpatchedCriticalDays(); d != -1 {
		t.Fatalf("patched critical must not appear in panel, got %d", d)
	}
}

// TestSLAPanelBreachTriggersPagerDuty verifies that a critical CVE older than
// SLA is flagged as a PagerDuty-level event (days > 0 AND days > SLA).
func TestSLAPanelBreachTriggersPagerDuty(t *testing.T) {
	const slaDays = 7
	entry := cve.Entry{
		Severity:     cve.SeverityCritical,
		DiscoveredAt: time.Now().Add(-time.Duration(slaDays+1) * 24 * time.Hour),
	}
	if !entry.SLABreached() {
		t.Fatal("entry older than SLA must report breach")
	}
	if entry.DaysSinceDiscovery() <= slaDays {
		t.Fatalf("expected >%d days since discovery", slaDays)
	}
}

// TestSLAPanelHighSLA verifies the high-severity SLA is 30 days.
func TestSLAPanelHighSLA(t *testing.T) {
	// 31-day-old high CVE is breached.
	old := cve.Entry{
		Severity:     cve.SeverityHigh,
		DiscoveredAt: time.Now().Add(-31 * 24 * time.Hour),
	}
	if !old.SLABreached() {
		t.Fatal("31-day-old high severity should be SLA-breached")
	}

	// 29-day-old high CVE is not breached.
	recent := cve.Entry{
		Severity:     cve.SeverityHigh,
		DiscoveredAt: time.Now().Add(-29 * 24 * time.Hour),
	}
	if recent.SLABreached() {
		t.Fatal("29-day-old high severity should NOT be SLA-breached")
	}
}
