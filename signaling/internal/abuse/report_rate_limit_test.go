package abuse

import (
	"testing"
)

// TestPeerReportRateLimitBlocks verifies that a reporter is blocked after
// 5 peer-game reports in a 24-hour window (§14.3 report-bombing defense).
func TestPeerReportRateLimitBlocks(t *testing.T) {
	store := NewStore()

	reporter := "fp-spammer"
	opponent := "fp-target"

	for i := 0; i < maxPeerReportsPerDay; i++ {
		r := &PeerGameReport{
			ReporterFingerprintRaw: reporter,
			OpponentFingerprint:    opponent,
			Reason:                 ReasonHarassment,
		}
		if err := store.File(r); err != nil {
			t.Fatalf("report %d unexpected error: %v", i, err)
		}
	}

	// The (maxPeerReportsPerDay + 1)-th report must be rate-limited.
	over := &PeerGameReport{
		ReporterFingerprintRaw: reporter,
		OpponentFingerprint:    opponent,
		Reason:                 ReasonOther,
	}
	err := store.File(over)
	if err == nil {
		t.Fatal("expected rate-limit error, got nil")
	}
	if err != ErrReportRateLimitedPeer {
		t.Fatalf("error = %v, want ErrReportRateLimitedPeer", err)
	}
}

// TestPeerReportRateLimitDoesNotAffectOtherReporters verifies that one
// reporter being rate-limited does not block a different reporter.
func TestPeerReportRateLimitDoesNotAffectOtherReporters(t *testing.T) {
	store := NewStore()

	spammer := "fp-spammer"
	innocent := "fp-innocent"
	opponent := "fp-target"

	// Exhaust spammer's quota.
	for i := 0; i < maxPeerReportsPerDay; i++ {
		_ = store.File(&PeerGameReport{
			ReporterFingerprintRaw: spammer,
			OpponentFingerprint:    opponent,
			Reason:                 ReasonHarassment,
		})
	}

	// Innocent reporter should still be allowed.
	if err := store.File(&PeerGameReport{
		ReporterFingerprintRaw: innocent,
		OpponentFingerprint:    opponent,
		Reason:                 ReasonThreats,
	}); err != nil {
		t.Fatalf("innocent reporter was rate-limited: %v", err)
	}
}

// TestPeerReportRateLimitExactlyAtBoundary verifies that exactly
// maxPeerReportsPerDay reports are accepted and the (max+1)-th is rejected.
func TestPeerReportRateLimitExactlyAtBoundary(t *testing.T) {
	store := NewStore()
	reporter := "fp-boundary"

	for i := 0; i < maxPeerReportsPerDay; i++ {
		err := store.File(&PeerGameReport{
			ReporterFingerprintRaw: reporter,
			OpponentFingerprint:    "fp-opp",
			Reason:                 ReasonOther,
		})
		if err != nil {
			t.Fatalf("report %d/%d unexpectedly rejected: %v", i+1, maxPeerReportsPerDay, err)
		}
	}

	err := store.File(&PeerGameReport{
		ReporterFingerprintRaw: reporter,
		OpponentFingerprint:    "fp-opp",
		Reason:                 ReasonOther,
	})
	if err != ErrReportRateLimitedPeer {
		t.Fatalf("report %d should be rate-limited, got: %v", maxPeerReportsPerDay+1, err)
	}
}
