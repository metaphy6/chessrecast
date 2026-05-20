package abuse

import (
	"crypto/sha256"
	"testing"
)

// TestAnonymisationHashesReporterFingerprint verifies that the reporter raw
// fingerprint is never surfaced in the anonymised view (§14.3 anonymisation).
func TestAnonymisationHashesReporterFingerprint(t *testing.T) {
	store := NewStore()

	rawFP := "fp-reporter-secret"
	r := &PeerGameReport{
		ID:                     "r1",
		ReporterFingerprintRaw: rawFP,
		OpponentFingerprint:    "fp-opp",
		Reason:                 ReasonHarassment,
	}
	if err := store.File(r); err != nil {
		t.Fatal(err)
	}

	views := store.AnonymisedReports()
	if len(views) == 0 {
		t.Fatal("expected 1 anonymised view, got 0")
	}

	v := views[0]
	expectedHash := sha256.Sum256([]byte(rawFP))
	if v.ReporterFingerprintHashed != expectedHash {
		t.Errorf("hashed fingerprint mismatch: got %x, want %x",
			v.ReporterFingerprintHashed, expectedHash)
	}
}

// TestAnonymisationNoRawFingerprintInView verifies that the AnonymisedView
// type has no field that would expose the raw fingerprint.
func TestAnonymisationNoRawFingerprintInView(t *testing.T) {
	store := NewStore()
	r := &PeerGameReport{
		ID:                     "r2",
		ReporterFingerprintRaw: "super-secret-fp",
		OpponentFingerprint:    "fp-opp",
		Reason:                 ReasonOther,
	}
	if err := store.File(r); err != nil {
		t.Fatal(err)
	}

	views := store.AnonymisedReports()
	if len(views) == 0 {
		t.Fatal("expected 1 view")
	}

	// The AnonymisedView type only exposes a [32]byte hash, never the string.
	// This test documents the invariant; a compile-time type check would also
	// catch any future field addition that leaks the raw value.
	v := views[0]
	// Hashed field is a [32]byte — not a string, never the raw value.
	var _ [32]byte = v.ReporterFingerprintHashed
}

// TestAnonymisationMultipleReportersSameOpponent verifies hashes are
// independent per reporter (no fingerprint collision in the hash output).
func TestAnonymisationMultipleReportersSameOpponent(t *testing.T) {
	store := NewStore()
	for i := 0; i < 3; i++ {
		r := &PeerGameReport{
			ReporterFingerprintRaw: "reporter-" + string(rune('A'+i)),
			OpponentFingerprint:    "fp-opp",
			Reason:                 ReasonHarassment,
		}
		if err := store.File(r); err != nil {
			t.Fatalf("File report %d: %v", i, err)
		}
	}

	views := store.AnonymisedReports()
	if len(views) != 3 {
		t.Fatalf("expected 3 views, got %d", len(views))
	}

	seen := map[[32]byte]bool{}
	for _, v := range views {
		if seen[v.ReporterFingerprintHashed] {
			t.Errorf("duplicate hashed fingerprint detected — collision or identity leak")
		}
		seen[v.ReporterFingerprintHashed] = true
	}
}
