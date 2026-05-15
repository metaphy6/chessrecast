package cve_test

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/cve"
)

// TestCVEQueueRoundTrip verifies that entries written to the queue are
// persisted to disk and can be read back.
func TestCVEQueueRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "queue.json")

	q, err := cve.OpenQueue(path)
	if err != nil {
		t.Fatalf("OpenQueue: %v", err)
	}

	e := cve.Entry{
		ID:           "GHSA-1234-abcd-efgh",
		Package:      "golang.org/x/crypto",
		Severity:     cve.SeverityCritical,
		Description:  "synthetic test CVE",
		DiscoveredAt: time.Now().Add(-24 * time.Hour),
	}
	if err := q.Add(e); err != nil {
		t.Fatalf("Add: %v", err)
	}

	// Re-open from disk.
	q2, err := cve.OpenQueue(path)
	if err != nil {
		t.Fatalf("re-open: %v", err)
	}
	entries := q2.Entries()
	if len(entries) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(entries))
	}
	if entries[0].ID != e.ID {
		t.Fatalf("id mismatch: got %q, want %q", entries[0].ID, e.ID)
	}
}

// TestCVESLADays verifies the SLA schedule: critical=7, high=30, medium=90, low=365.
func TestCVESLADays(t *testing.T) {
	cases := []struct {
		s    cve.Severity
		want int
	}{
		{cve.SeverityCritical, 7},
		{cve.SeverityHigh, 30},
		{cve.SeverityMedium, 90},
		{cve.SeverityLow, 365},
	}
	for _, c := range cases {
		if got := cve.SLADays(c.s); got != c.want {
			t.Errorf("SLADays(%q) = %d, want %d", c.s, got, c.want)
		}
	}
}

// TestCVESLABreached verifies that an unpatched critical CVE older than 7 days
// is flagged as SLA-breached, and a recently discovered one is not.
func TestCVESLABreached(t *testing.T) {
	old := cve.Entry{
		Severity:     cve.SeverityCritical,
		DiscoveredAt: time.Now().Add(-8 * 24 * time.Hour), // 8 days ago
	}
	if !old.SLABreached() {
		t.Fatal("8-day-old unpatched critical should be SLA-breached")
	}

	fresh := cve.Entry{
		Severity:     cve.SeverityCritical,
		DiscoveredAt: time.Now().Add(-1 * time.Hour),
	}
	if fresh.SLABreached() {
		t.Fatal("1-hour-old unpatched critical should NOT be SLA-breached")
	}
}

// TestCVEUnpatchedCriticalDays verifies UnpatchedCriticalDays returns correct value.
func TestCVEUnpatchedCriticalDays(t *testing.T) {
	dir := t.TempDir()
	q, _ := cve.OpenQueue(filepath.Join(dir, "q.json"))

	if d := q.UnpatchedCriticalDays(); d != -1 {
		t.Fatalf("empty queue should return -1, got %d", d)
	}

	q.Add(cve.Entry{
		ID:           "TEST-001",
		Severity:     cve.SeverityCritical,
		DiscoveredAt: time.Now().Add(-3 * 24 * time.Hour),
	})
	if d := q.UnpatchedCriticalDays(); d != 3 {
		t.Fatalf("expected 3 days, got %d", d)
	}
}

// TestCVEWatcherQueueFileCreated verifies that OpenQueue creates the file on first open.
func TestCVEWatcherQueueFileCreated(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "new_queue.json")
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("file should not exist before first open")
	}
	q, err := cve.OpenQueue(path)
	if err != nil {
		t.Fatalf("OpenQueue on missing file: %v", err)
	}
	// Add an entry to force the save.
	q.Add(cve.Entry{ID: "X", Severity: cve.SeverityLow, DiscoveredAt: time.Now()})
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("queue file should be created after Add: %v", err)
	}
}
