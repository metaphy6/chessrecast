// Package push manages APNs/FCM push token registration and wakeup.
package push

import (
	"fmt"
	"sync"
	"time"
)

// WakeCeiling is the maximum push wakeups allowed per (sender, recipient) pair per day.
const WakeCeiling = 50

// BackoffThreshold is the number of ignored wakes before exponential backoff kicks in.
const BackoffThreshold = 5

// WakeRecord tracks daily wakeup counts per (sender→recipient) pair.
type WakeRecord struct {
	Count    int
	LastDate string // "YYYY-MM-DD"
	Ignored  int    // consecutive ignored wakes
}

// WakeTracker enforces per-(sender, recipient) push wake limits.
type WakeTracker struct {
	mu      sync.Mutex
	records map[string]*WakeRecord
}

// NewWakeTracker returns an empty WakeTracker.
func NewWakeTracker() *WakeTracker {
	return &WakeTracker{records: make(map[string]*WakeRecord)}
}

// recordKey returns the map key for a sender→recipient pair.
func recordKey(sender, recipient string) string {
	return sender + "\x00" + recipient
}

// today returns the current UTC date as "YYYY-MM-DD".
func today() string {
	return time.Now().UTC().Format("2006-01-02")
}

// Allow returns nil if the wake is permitted, or an error if the daily ceiling
// or backoff prevents it.
func (t *WakeTracker) Allow(sender, recipient string) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	key := recordKey(sender, recipient)
	rec, ok := t.records[key]
	if !ok {
		rec = &WakeRecord{}
		t.records[key] = rec
	}
	d := today()
	if rec.LastDate != d {
		rec.Count = 0
		rec.LastDate = d
	}
	if rec.Count >= WakeCeiling {
		return fmt.Errorf("push wake ceiling reached (%d/day)", WakeCeiling)
	}
	if rec.Ignored >= BackoffThreshold {
		// Exponential backoff: only allow every 2^(ignored-BackoffThreshold) minutes.
		// For this implementation we simply reject after BackoffThreshold consecutive ignores.
		return fmt.Errorf("recipient not responding: exponential backoff in effect (ignored=%d)", rec.Ignored)
	}
	rec.Count++
	return nil
}

// RecordIgnored increments the ignored-wake counter for a pair (called when the peer did not respond).
func (t *WakeTracker) RecordIgnored(sender, recipient string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	key := recordKey(sender, recipient)
	rec, ok := t.records[key]
	if !ok {
		rec = &WakeRecord{}
		t.records[key] = rec
	}
	rec.Ignored++
}

// RecordResponded resets the ignored-wake counter for a pair (called when the peer responds).
func (t *WakeTracker) RecordResponded(sender, recipient string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	key := recordKey(sender, recipient)
	if rec, ok := t.records[key]; ok {
		rec.Ignored = 0
	}
}

// ReregistrationInterval is the server-driven hint interval for push tokens.
const ReregistrationInterval = 30 * 24 * time.Hour

// StalePushTokenTTL is the age beyond which a push token is evicted server-side.
const StalePushTokenTTL = 90 * 24 * time.Hour

// NeedsReregistration returns true if the token was last registered more than
// ReregistrationInterval ago (server-driven re-registration hint).
func NeedsReregistration(lastRegisteredAt time.Time) bool {
	return time.Since(lastRegisteredAt) > ReregistrationInterval
}

// IsStale returns true if the token is older than StalePushTokenTTL and should
// be evicted by the server-side GC job.
func IsStale(lastRegisteredAt time.Time) bool {
	return time.Since(lastRegisteredAt) > StalePushTokenTTL
}

