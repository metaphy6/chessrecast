package server_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"

	"github.com/chessrecast/signaling/internal/server"
)

// TestLongPollCap verifies that beyond the per-account concurrent long-poll cap (32),
// subsequent requests receive HTTP 429.
func TestLongPollCap(t *testing.T) {
	const cap = server.MaxLongPollsPerAccount
	deps := &server.Deps{AdminToken: "tok", DBReady: true, PushReady: true}
	tracker := server.NewPollTracker()

	// Simulate cap concurrent polls by calling Allow cap times.
	for i := 0; i < cap; i++ {
		if !tracker.Allow("acct-pub") {
			t.Fatalf("poll %d should be allowed (below cap)", i+1)
		}
	}

	// The cap+1th poll must be denied.
	if tracker.Allow("acct-pub") {
		t.Fatalf("poll %d should be rejected (at cap=%d)", cap+1, cap)
	}

	// A different account must still be allowed.
	if !tracker.Allow("other-pub") {
		t.Fatal("fresh account should be allowed")
	}

	_ = deps
}

// TestLongPollCapRelease verifies that releasing a slot (poll done) allows a new one.
func TestLongPollCapRelease(t *testing.T) {
	const cap = server.MaxLongPollsPerAccount
	tracker := server.NewPollTracker()

	for i := 0; i < cap; i++ {
		tracker.Allow("acct-x")
	}
	if tracker.Allow("acct-x") {
		t.Fatal("expected rejection at cap")
	}
	tracker.Release("acct-x")
	if !tracker.Allow("acct-x") {
		t.Fatal("expected allow after release")
	}
}

// TestHTTP429OnPollCapExceeded wires the tracker into the actual route and verifies
// the HTTP response is 429 with Retry-After header.
func TestHTTP429OnPollCapExceeded(t *testing.T) {
	deps := &server.Deps{AdminToken: "tok", DBReady: true, PushReady: true,
		PollTracker: server.NewPollTracker()}
	h := server.NewRouter(deps)

	// Exhaust the tracker externally.
	for i := 0; i < server.MaxLongPollsPerAccount; i++ {
		deps.PollTracker.Allow("acct-cap-test")
	}

	req := httptest.NewRequest(http.MethodGet,
		"/v1/offers/poll?account_pub=acct-cap-test&device_pub=dev1", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("expected 429, got %d", rec.Code)
	}
	if rec.Header().Get("Retry-After") == "" {
		t.Fatal("expected Retry-After header")
	}
}

// TestPendingOfferCapFIFO verifies that the per-account pending-offer cap (16) evicts oldest.
func TestPendingOfferCapFIFO(t *testing.T) {
	q := server.NewOfferQueue(16)
	acct := "recipient-pub"

	// Fill to cap.
	for i := 0; i < 16; i++ {
		q.Enqueue(acct, fmt.Sprintf("offer-%d", i))
	}
	if n := q.Len(acct); n != 16 {
		t.Fatalf("expected 16 pending offers, got %d", n)
	}
	// Enqueue one more — oldest must be evicted.
	q.Enqueue(acct, "offer-new")
	if n := q.Len(acct); n != 16 {
		t.Fatalf("queue length should stay at cap=16, got %d", n)
	}
	// The first offer should have been evicted.
	offers := q.Drain(acct)
	for _, o := range offers {
		if o == "offer-0" {
			t.Fatal("oldest offer should have been evicted")
		}
	}
}

// TestProcessLimitsConstants verifies that the process-level cap constants are defined.
func TestProcessLimitsConstants(t *testing.T) {
	if server.RLimitNoFile == 0 {
		t.Fatal("RLimitNoFile must be non-zero")
	}
	if server.GoMemLimitPct == 0 {
		t.Fatal("GoMemLimitPct must be non-zero")
	}
	// Sanity: GOMEMLIMIT fraction should be between 50% and 100%.
	if server.GoMemLimitPct < 50 || server.GoMemLimitPct > 100 {
		t.Fatalf("GoMemLimitPct=%d out of range [50,100]", server.GoMemLimitPct)
	}
	_ = sync.Mutex{}
}
