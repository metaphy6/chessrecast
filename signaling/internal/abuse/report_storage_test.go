package abuse

import (
	"crypto/sha256"
	"testing"
	"time"
)

// TestReportStorageFileAndRetrieve verifies that a filed report is stored and
// retrievable in anonymised form (§14.3 report_storage proof).
func TestReportStorageFileAndRetrieve(t *testing.T) {
	store := NewStore()

	r := &PeerGameReport{
		ID:                     "report-001",
		SessionID:              "sess-abc",
		ReporterFingerprintRaw: "fp-reporter-raw",
		OpponentFingerprint:    "fp-opponent",
		Reason:                 ReasonHarassment,
		TranscriptHash:         sha256.Sum256([]byte("game transcript")),
	}

	if err := store.File(r); err != nil {
		t.Fatalf("File() unexpected error: %v", err)
	}

	if got := store.Len(); got != 1 {
		t.Fatalf("Len() = %d, want 1", got)
	}

	views := store.AnonymisedReports()
	if len(views) != 1 {
		t.Fatalf("AnonymisedReports() len = %d, want 1", len(views))
	}

	v := views[0]
	if v.OpponentFingerprint != "fp-opponent" {
		t.Errorf("opponent fingerprint = %q, want %q", v.OpponentFingerprint, "fp-opponent")
	}
	if v.Reason != ReasonHarassment {
		t.Errorf("reason = %v, want %v", v.Reason, ReasonHarassment)
	}
}

// TestReportStoragePurge verifies that reports older than 90 days are purged.
func TestReportStoragePurge(t *testing.T) {
	store := NewStore()

	old := &PeerGameReport{
		ID:                     "old",
		ReporterFingerprintRaw: "fp-x",
		OpponentFingerprint:    "fp-y",
		Reason:                 ReasonOther,
	}
	if err := store.File(old); err != nil {
		t.Fatal(err)
	}
	// Backdate the record.
	store.mu.Lock()
	store.reports[0].CreatedAt = time.Now().Add(-91 * 24 * time.Hour)
	store.mu.Unlock()

	purged := store.PurgeExpired()
	if purged != 1 {
		t.Fatalf("PurgeExpired() = %d, want 1", purged)
	}
	if store.Len() != 0 {
		t.Fatalf("Len() after purge = %d, want 0", store.Len())
	}
}

// TestReportStorageNotPurgedYoung verifies reports < 90 days are retained.
func TestReportStorageNotPurgedYoung(t *testing.T) {
	store := NewStore()
	r := &PeerGameReport{
		ID:                     "new",
		ReporterFingerprintRaw: "fp-reporter",
		OpponentFingerprint:    "fp-opp",
		Reason:                 ReasonThreats,
	}
	if err := store.File(r); err != nil {
		t.Fatal(err)
	}
	purged := store.PurgeExpired()
	if purged != 0 {
		t.Fatalf("PurgeExpired() = %d, want 0 for a young report", purged)
	}
	if store.Len() != 1 {
		t.Fatalf("Len() = %d, want 1", store.Len())
	}
}
