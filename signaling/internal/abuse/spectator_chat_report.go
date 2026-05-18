// Package abuse extends the existing abuse reporting (§14) with
// spectator-chat report handling (§7.9.7).
package abuse

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"sync"
	"time"
)

// ErrReportRateLimited is returned when a reporter exceeds 5 reports / 24 h.
var ErrReportRateLimited = errors.New("abuse: spectator chat report rate limited")

// SpectatorChatReportPayload is the payload for a spectator-chat abuse report.
type SpectatorChatReportPayload struct {
	ReporterPubKeyHex string
	TargetPubKeyHex   string
	GameID            string
	MessageHash       [32]byte
	// Optional: a redacted excerpt (max 100 chars) for human review.
	RedactedExcerpt string
}

// ComputeMessageHash hashes [ciphertext] to produce a stable report reference.
func ComputeMessageHash(ciphertext []byte) [32]byte {
	return sha256.Sum256(ciphertext)
}

// SpectatorChatReporter enforces per-account rate limits and enqueues reports
// to the §14 review queue.
type SpectatorChatReporter struct {
	mu         sync.Mutex
	// reporter pubkey hex → list of report timestamps
	timestamps map[string][]time.Time
	// queued reports (in production these would be written to the store)
	queue []*SpectatorChatReportPayload
}

const (
	maxReportsPerDay = 5
	dayDuration      = 24 * time.Hour
)

// NewSpectatorChatReporter creates a new reporter.
func NewSpectatorChatReporter() *SpectatorChatReporter {
	return &SpectatorChatReporter{
		timestamps: make(map[string][]time.Time),
	}
}

// File records an abuse report.
//
// Returns ErrReportRateLimited when the reporter has filed ≥ 5 reports in 24 h.
func (r *SpectatorChatReporter) File(p *SpectatorChatReportPayload) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	now := time.Now()
	ts := r.timestamps[p.ReporterPubKeyHex]
	// Prune old.
	pruned := ts[:0]
	for _, t := range ts {
		if now.Sub(t) < dayDuration {
			pruned = append(pruned, t)
		}
	}
	r.timestamps[p.ReporterPubKeyHex] = pruned

	if len(pruned) >= maxReportsPerDay {
		return fmt.Errorf("%w (reporter=%s)", ErrReportRateLimited, p.ReporterPubKeyHex)
	}

	r.timestamps[p.ReporterPubKeyHex] = append(r.timestamps[p.ReporterPubKeyHex], now)
	r.queue = append(r.queue, p)
	return nil
}

// QueueDepth returns the number of queued reports (for testing).
func (r *SpectatorChatReporter) QueueDepth() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.queue)
}

// ReportsToday returns the number of reports filed by [reporterPubKeyHex] in the last 24 h.
func (r *SpectatorChatReporter) ReportsToday(reporterPubKeyHex string) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	now := time.Now()
	count := 0
	for _, t := range r.timestamps[reporterPubKeyHex] {
		if now.Sub(t) < dayDuration {
			count++
		}
	}
	return count
}
