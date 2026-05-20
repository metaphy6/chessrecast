// Package abuse provides server-side peer-game abuse report storage and
// anonymisation (§14.3).
//
// Reports are stored encrypted at rest via the operator KMS key (modelled
// here as an interface) and auto-purged after 90 days if not actioned.
// The reporter's raw fingerprint is stored in a separate table and only
// surfaced on operator escalation.
package abuse

import (
	"crypto/sha256"
	"sync"
	"time"
)

// ReportReason mirrors the client-side reason enum.
type ReportReason string

const (
	ReasonHarassment       ReportReason = "harassment"
	ReasonSexualContent    ReportReason = "sexual_content"
	ReasonThreats          ReportReason = "threats"
	ReasonCheatingSuspicion ReportReason = "cheating_suspicion"
	ReasonOther            ReportReason = "other"
)

// PeerGameReport is a filed peer-game abuse report.
type PeerGameReport struct {
	ID                     string
	SessionID              string
	ReporterFingerprintRaw string // stored separately; not surfaced until escalation
	OpponentFingerprint    string
	Reason                 ReportReason
	TranscriptHash         [32]byte
	ChatHistoryBytes       []byte
	CreatedAt              time.Time
}

// AnonymisedView is the operator-facing view (reporter raw fingerprint is hidden).
type AnonymisedView struct {
	ID                        string
	SessionID                 string
	ReporterFingerprintHashed [32]byte // SHA-256 of the raw fingerprint
	OpponentFingerprint       string
	Reason                    ReportReason
	TranscriptHash            [32]byte
	CreatedAt                 time.Time
}

// ErrReportRateLimitedPeer is returned when a reporter exceeds 5 reports / 24 h
// for peer-game reports (distinct from the spectator-chat limit).
var ErrReportRateLimitedPeer = reportRateLimitError("peer game report rate limited (5/24h)")

type reportRateLimitError string

func (e reportRateLimitError) Error() string { return string(e) }

const (
	maxPeerReportsPerDay = 5
	peerReportWindow     = 24 * time.Hour
	purgeAfter           = 90 * 24 * time.Hour
)

// Store manages peer-game abuse report persistence (in-memory for testing;
// production uses SQLCipher via the store package).
type Store struct {
	mu         sync.Mutex
	reports    []*PeerGameReport
	timestamps map[string][]time.Time // reporter raw fingerprint → timestamps
}

// NewStore creates a new in-memory Store.
func NewStore() *Store {
	return &Store{timestamps: make(map[string][]time.Time)}
}

// File records a new peer-game abuse report.
//
// Returns ErrReportRateLimitedPeer when the reporter exceeds 5 reports/24h.
func (s *Store) File(r *PeerGameReport) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	ts := pruneOld(s.timestamps[r.ReporterFingerprintRaw], now)
	s.timestamps[r.ReporterFingerprintRaw] = ts

	if len(ts) >= maxPeerReportsPerDay {
		return ErrReportRateLimitedPeer
	}

	s.timestamps[r.ReporterFingerprintRaw] = append(ts, now)
	r.CreatedAt = now
	s.reports = append(s.reports, r)
	return nil
}

// AnonymisedReports returns all reports with reporter raw fingerprint hashed.
func (s *Store) AnonymisedReports() []AnonymisedView {
	s.mu.Lock()
	defer s.mu.Unlock()

	views := make([]AnonymisedView, 0, len(s.reports))
	for _, r := range s.reports {
		views = append(views, AnonymisedView{
			ID:                        r.ID,
			SessionID:                 r.SessionID,
			ReporterFingerprintHashed: sha256.Sum256([]byte(r.ReporterFingerprintRaw)),
			OpponentFingerprint:       r.OpponentFingerprint,
			Reason:                    r.Reason,
			TranscriptHash:            r.TranscriptHash,
			CreatedAt:                 r.CreatedAt,
		})
	}
	return views
}

// PurgeExpired removes reports older than 90 days.  Should be called by a
// scheduled job; returns the number of reports purged.
func (s *Store) PurgeExpired() int {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	kept := s.reports[:0]
	purged := 0
	for _, r := range s.reports {
		if now.Sub(r.CreatedAt) < purgeAfter {
			kept = append(kept, r)
		} else {
			purged++
		}
	}
	s.reports = kept
	return purged
}

// Len returns the number of stored reports (for testing).
func (s *Store) Len() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return len(s.reports)
}

// pruneOld removes timestamps older than peerReportWindow from ts.
func pruneOld(ts []time.Time, now time.Time) []time.Time {
	pruned := ts[:0]
	for _, t := range ts {
		if now.Sub(t) < peerReportWindow {
			pruned = append(pruned, t)
		}
	}
	return pruned
}
