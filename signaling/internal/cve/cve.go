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

// EnforceMinVersion checks whether clientVersion satisfies the highest
// min_client_version requirement set by any unpatched CVE entry.
// Returns (true, nil) if the client is allowed, (false, *Entry) if it is
// blocked and must receive HTTP 426 CVE_REQUIRES_FORCED_UPDATE.
func (q *Queue) EnforceMinVersion(clientVersion string) (bool, *Entry) {
	q.mu.RLock()
	defer q.mu.RUnlock()
	for i := range q.entries {
		e := &q.entries[i]
		if e.MinClientVersion == "" || e.IsPatched() {
			continue
		}
		if compareVersions(clientVersion, e.MinClientVersion) < 0 {
			return false, e
		}
	}
	return true, nil
}

// compareVersions compares two semver-like version strings ("1.2.3").
// Returns -1 if a < b, 0 if equal, +1 if a > b.
// Only the three numeric components are compared; pre-release suffixes are
// ignored for simplicity (sufficient for the min_client_version gate).
func compareVersions(a, b string) int {
	av := parseVer(a)
	bv := parseVer(b)
	for i := range av {
		if av[i] < bv[i] {
			return -1
		}
		if av[i] > bv[i] {
			return 1
		}
	}
	return 0
}

// parseVer extracts the three numeric components from a semver string.
func parseVer(v string) [3]int {
	var major, minor, patch int
	fmt.Sscanf(v, "%d.%d.%d", &major, &minor, &patch)
	return [3]int{major, minor, patch}
}

// SecurityTxt returns the content of the /.well-known/security.txt endpoint
// (RFC 9116) including the per-severity patch SLA so users can read the
// disclosure policy (§16.1.2).
func SecurityTxt() string {
	return `# Security policy for Chess Recast P2P
# RFC 9116 — https://www.rfc-editor.org/rfc/rfc9116

Contact: https://github.com/chessrecast/chessrecast/security/advisories/new
Expires: 2027-01-01T00:00:00Z
Preferred-Languages: en

# Patch SLA (per CVSS severity)
# Critical : 7 days  — forced update via min_client_version (HTTP 426)
# High     : 30 days — patched build + optional forced update
# Medium   : 90 days — included in next regular release
# Low      : next release (≤ 365 days)
#
# Full CVE playbook: https://github.com/chessrecast/chessrecast/blob/main/docs/P2P_OPERATIONS.md
`
}

// Dependency-bump policy constants (§16.4).

// DepPolicyMajorCryptoRequiresSharedEdit declares that major-version bumps in
// cryptographic dependencies (libsodium, Go-stdlib crypto, Flutter cryptography)
// require a queue entry of kind:shared_edit with a written rationale.
const DepPolicyMajorCryptoRequiresSharedEdit = true

// DepPolicyMajorCryptoRequiresKATRepass declares that major crypto dep bumps
// must pass a regenerated KAT-vector test suite before merging.
const DepPolicyMajorCryptoRequiresKATRepass = true

// DepPolicyAutoPRForceMergeDisabled declares that CVE-watcher auto-PRs for
// patch-level dependency bumps may not be force-merged; they must pass the
// full L1–L7 suite (§16.4.2).
const DepPolicyAutoPRForceMergeDisabled = true

// Deprecation policy constants (§16.5).

// SunsetWindowWireVersion is the minimum duration between a soft-deprecation
// announcement and a hard-deprecation floor bump for wire_version and
// crypto_suite_id (§16.5.3).
const SunsetWindowWireVersion = 90 * 24 * time.Hour

// SunsetWindowEngineReplay is the minimum duration between soft- and
// hard-deprecation for engine_replay_version (§16.5.3).
const SunsetWindowEngineReplay = 30 * 24 * time.Hour

// Hard-deprecation error codes (§10.3 v7, §16.5.2).
const (
	CodeDeprecatedWireVersionRejected          = "DEPRECATED_WIRE_VERSION_REJECTED"
	CodeDeprecatedCryptoSuiteRejected          = "DEPRECATED_CRYPTO_SUITE_REJECTED"
	CodeDeprecatedEngineReplayVersionRejected  = "DEPRECATED_ENGINE_REPLAY_VERSION_REJECTED"
)
