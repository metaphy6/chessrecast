// Package cve provides the CVE-watcher service and SLA-dashboard logic (§3.10).
package cve

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"
)

// Severity is the CVSS-derived severity tier for a CVE entry.
type Severity string

const (
	SeverityCritical Severity = "critical"
	SeverityHigh     Severity = "high"
	SeverityMedium   Severity = "medium"
	SeverityLow      Severity = "low"
)

// SLADays returns the patch SLA in days for a given severity level.
// critical → 7 d, high → 30 d, medium → 90 d, low → next release (365 d cap).
func SLADays(s Severity) int {
	switch s {
	case SeverityCritical:
		return 7
	case SeverityHigh:
		return 30
	case SeverityMedium:
		return 90
	default:
		return 365
	}
}

// Entry is a single CVE advisory record.
type Entry struct {
	ID          string    `json:"id"`
	Package     string    `json:"package"`
	Severity    Severity  `json:"severity"`
	Description string    `json:"description"`
	DiscoveredAt time.Time `json:"discovered_at"`
	PatchedAt   *time.Time `json:"patched_at,omitempty"`
	MinClientVersion string `json:"min_client_version,omitempty"`
}

// IsPatched returns true if a patched_at timestamp has been set.
func (e Entry) IsPatched() bool { return e.PatchedAt != nil }

// DaysSinceDiscovery returns the number of whole days since the CVE was discovered.
func (e Entry) DaysSinceDiscovery() int {
	return int(time.Since(e.DiscoveredAt).Hours() / 24)
}

// SLABreached returns true if the entry is unpatched and has exceeded its SLA.
func (e Entry) SLABreached() bool {
	if e.IsPatched() {
		return false
	}
	return e.DaysSinceDiscovery() > SLADays(e.Severity)
}

// Queue is an in-process CVE queue backed by a JSON file.
type Queue struct {
	mu      sync.RWMutex
	entries []Entry
	path    string
}

// OpenQueue opens (or creates) the CVE queue at the given JSON file path.
func OpenQueue(path string) (*Queue, error) {
	q := &Queue{path: path}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return q, nil
		}
		return nil, fmt.Errorf("open cve queue: %w", err)
	}
	if err := json.Unmarshal(data, &q.entries); err != nil {
		return nil, fmt.Errorf("parse cve queue: %w", err)
	}
	return q, nil
}

// Add appends an entry to the queue and persists it.
func (q *Queue) Add(e Entry) error {
	q.mu.Lock()
	defer q.mu.Unlock()
	q.entries = append(q.entries, e)
	return q.save()
}

// Entries returns a copy of all entries.
func (q *Queue) Entries() []Entry {
	q.mu.RLock()
	defer q.mu.RUnlock()
	out := make([]Entry, len(q.entries))
	copy(out, q.entries)
	return out
}

// UnpatchedCriticalDays returns the number of days since the most recent
// unpatched critical CVE was discovered, or -1 if none exist.
func (q *Queue) UnpatchedCriticalDays() int {
	q.mu.RLock()
	defer q.mu.RUnlock()
	best := -1
	for _, e := range q.entries {
		if e.Severity == SeverityCritical && !e.IsPatched() {
			d := e.DaysSinceDiscovery()
			if best == -1 || d > best {
				best = d
			}
		}
	}
	return best
}

func (q *Queue) save() error {
	data, err := json.MarshalIndent(q.entries, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(q.path, data, 0o600)
}
