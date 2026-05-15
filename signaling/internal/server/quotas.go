// Package server: resource quota helpers (§3.9).
package server

import (
	"sync"
)

// MaxLongPollsPerAccount is the maximum number of concurrent long-poll
// connections allowed per account public key (§3.9).
const MaxLongPollsPerAccount = 32

// RLimitNoFile is the fd ceiling the process should set via RLIMIT_NOFILE.
// At 60k it comfortably fits 32 polls * N accounts + headroom.
const RLimitNoFile = 65536

// GoMemLimitPct is the percentage of the container memory limit that is
// forwarded to GOMEMLIMIT so the GC acts before the OOM killer fires.
const GoMemLimitPct = 90

// PollTracker tracks the number of active long-poll connections per account.
type PollTracker struct {
	mu     sync.Mutex
	counts map[string]int
}

// NewPollTracker returns an empty PollTracker.
func NewPollTracker() *PollTracker {
	return &PollTracker{counts: make(map[string]int)}
}

// Allow returns true and increments the counter if the account is below the cap.
// Returns false if the account has already reached MaxLongPollsPerAccount.
func (t *PollTracker) Allow(accountPub string) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.counts[accountPub] >= MaxLongPollsPerAccount {
		return false
	}
	t.counts[accountPub]++
	return true
}

// Release decrements the counter for an account when a long-poll connection
// closes.
func (t *PollTracker) Release(accountPub string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.counts[accountPub] > 0 {
		t.counts[accountPub]--
	}
}

// OfferQueue is a per-account bounded FIFO queue for pending offers (§3.9).
type OfferQueue struct {
	mu   sync.Mutex
	cap  int
	data map[string][]string
}

// NewOfferQueue returns an OfferQueue with the given per-account capacity.
func NewOfferQueue(cap int) *OfferQueue {
	return &OfferQueue{cap: cap, data: make(map[string][]string)}
}

// Enqueue adds offerID to the recipient's queue. If the queue is at capacity,
// the oldest offer is evicted (FIFO).
func (q *OfferQueue) Enqueue(recipientPub, offerID string) {
	q.mu.Lock()
	defer q.mu.Unlock()
	items := q.data[recipientPub]
	if len(items) >= q.cap {
		items = items[1:] // evict oldest
	}
	q.data[recipientPub] = append(items, offerID)
}

// Len returns the number of pending offers for the given account.
func (q *OfferQueue) Len(recipientPub string) int {
	q.mu.Lock()
	defer q.mu.Unlock()
	return len(q.data[recipientPub])
}

// Drain removes and returns all pending offers for the given account.
func (q *OfferQueue) Drain(recipientPub string) []string {
	q.mu.Lock()
	defer q.mu.Unlock()
	items := q.data[recipientPub]
	delete(q.data, recipientPub)
	return items
}
