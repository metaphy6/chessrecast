package push_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/push"
)

// TestPushTokenReregistrationHint verifies that the server-side hint logic
// returns true (re-register needed) for tokens older than 30 days.
func TestPushTokenReregistrationHint(t *testing.T) {
	staleSince := time.Now().Add(-31 * 24 * time.Hour)
	if !push.NeedsReregistration(staleSince) {
		t.Fatal("token older than 30 days should require re-registration")
	}
}

// TestPushTokenFreshNoHint verifies that a fresh token does not trigger a hint.
func TestPushTokenFreshNoHint(t *testing.T) {
	freshSince := time.Now().Add(-5 * 24 * time.Hour)
	if push.NeedsReregistration(freshSince) {
		t.Fatal("fresh token should not require re-registration")
	}
}

// TestPushTokenStaleEviction verifies that tokens older than 90 days are evicted.
func TestPushTokenStaleEviction(t *testing.T) {
	stale := time.Now().Add(-91 * 24 * time.Hour)
	if !push.IsStale(stale) {
		t.Fatal("token older than 90 days should be stale")
	}

	fresh := time.Now().Add(-89 * 24 * time.Hour)
	if push.IsStale(fresh) {
		t.Fatal("token younger than 90 days should not be stale")
	}
}
