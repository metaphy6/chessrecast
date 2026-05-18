// Package spectator implements signaling-side spectator capacity, authentication,
// rate-limiting, and host-gone eviction (§7.8, §7.10.6).
package spectator

import (
	"fmt"
	"sync"
	"time"
)

// Error codes matching the Dart constants.
const (
	ErrCapacityFull    = "SPECTATOR_CAPACITY_FULL"
	ErrAuthRequired    = "SPECTATOR_AUTH_REQUIRED"
	ErrRateLimited     = "SPECTATOR_JOIN_RATE_LIMITED"
	ErrHostGone        = "SPECTATOR_HOST_GONE"
	ErrShedForPerf     = "SPECTATOR_SHED_FOR_PERF"
	ErrRelayUnavail    = "SPECTATOR_RELAY_UNAVAILABLE"
	ErrHeartbeatTimeout = "SPECTATOR_HEARTBEAT_TIMEOUT"
)

// Capacity constants (§7.8.2).
const (
	DefaultPerGameCap         = 50
	HardCeiling               = 200
	PerAccountCap             = 100
	WaitlistMaxDepth          = 50
	JoinRateLimitPerMinute    = 6
	JoinRateLimitPerHour      = 60
)

// Manager enforces capacity, auth, and rate-limit for a single game's spectators.
type Manager struct {
	mu           sync.Mutex
	gameID       string
	effectiveCap int
	seated       []string // account pubkey hexes
	waitlist     []string
	joins        map[string][]time.Time // per-account join timestamps
}

// NewManager creates a spectator manager for [gameID] with [cap] (clamped to HardCeiling).
func NewManager(gameID string, cap int) *Manager {
	if cap <= 0 {
		cap = DefaultPerGameCap
	}
	if cap > HardCeiling {
		cap = HardCeiling
	}
	return &Manager{
		gameID:       gameID,
		effectiveCap: cap,
		joins:        make(map[string][]time.Time),
	}
}

// AdmitResult is the outcome of an Admit call.
type AdmitResult struct {
	Seated    bool
	Waitlisted bool
	ErrCode   string
}

// Admit attempts to seat a spectator identified by [accountPubKeyHex].
//
// Enforces authentication, rate-limit, and capacity in that order.
// [isAuthenticated] must be true (v1 requirement: registered device pubkey).
func (m *Manager) Admit(accountPubKeyHex string, isAuthenticated bool) AdmitResult {
	m.mu.Lock()
	defer m.mu.Unlock()

	// §7.8.3 — authentication required.
	if !isAuthenticated {
		return AdmitResult{ErrCode: ErrAuthRequired}
	}

	// §7.8.4 — rate limit.
	now := time.Now()
	ts := m.joins[accountPubKeyHex]
	// Prune old entries.
	pruned := ts[:0]
	for _, t := range ts {
		if now.Sub(t) < time.Hour {
			pruned = append(pruned, t)
		}
	}
	m.joins[accountPubKeyHex] = pruned

	lastMinute := 0
	for _, t := range pruned {
		if now.Sub(t) < time.Minute {
			lastMinute++
		}
	}
	if lastMinute >= JoinRateLimitPerMinute || len(pruned) >= JoinRateLimitPerHour {
		return AdmitResult{ErrCode: ErrRateLimited}
	}
	m.joins[accountPubKeyHex] = append(m.joins[accountPubKeyHex], now)

	// §7.8.2 — capacity.
	if len(m.seated) < m.effectiveCap {
		m.seated = append(m.seated, accountPubKeyHex)
		return AdmitResult{Seated: true}
	}
	if len(m.waitlist) < WaitlistMaxDepth {
		m.waitlist = append(m.waitlist, accountPubKeyHex)
		return AdmitResult{Waitlisted: true}
	}
	return AdmitResult{ErrCode: ErrCapacityFull}
}

// Release removes a spectator from the seated list and promotes from waitlist.
func (m *Manager) Release(accountPubKeyHex string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.seated = removeFirst(m.seated, accountPubKeyHex)
	if len(m.waitlist) > 0 && len(m.seated) < m.effectiveCap {
		next := m.waitlist[0]
		m.waitlist = m.waitlist[1:]
		m.seated = append(m.seated, next)
	}
}

// SeatedCount returns the number of currently seated spectators.
func (m *Manager) SeatedCount() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return len(m.seated)
}

// ExpireWaitlist clears the waitlist (called when the game ends).
func (m *Manager) ExpireWaitlist() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.waitlist = nil
}

// HostGoneEviction sends a host-gone notice and clears all spectators within
// evictionTimeout. Returns the number of spectators evicted.
func (m *Manager) HostGoneEviction(evictionTimeout time.Duration) (int, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	count := len(m.seated)
	// In production this would send SPECTATOR_HOST_GONE notices via signaling
	// and await ACK or forcibly tear down after evictionTimeout.
	// For the stub, we clear immediately and note the timeout guarantee.
	if evictionTimeout <= 0 {
		return 0, fmt.Errorf("evictionTimeout must be > 0")
	}
	m.seated = nil
	m.waitlist = nil
	return count, nil
}

func removeFirst(list []string, val string) []string {
	for i, v := range list {
		if v == val {
			return append(list[:i], list[i+1:]...)
		}
	}
	return list
}
