// T-N-008 §9.1 — Short-lived offer sessions (≤ 5 minutes).
//
// Proof: store.OfferTTL ≤ 5 minutes, turn.TTL ≤ 5 minutes.
// These constants are the only session-lifetime commitments in the signaling
// server; no long-lived cookies or persistent offer tokens exist.
package store_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/store"
	"github.com/chessrecast/signaling/internal/turn"
)

// TestOfferTTLIsShortLived verifies §9.1 T-N-008: offer sessions must not
// exceed five minutes so an intercepted offer becomes useless quickly.
func TestOfferTTLIsShortLived(t *testing.T) {
	const maxAllowed = 5 * time.Minute
	if store.OfferTTL > maxAllowed {
		t.Errorf("store.OfferTTL = %v; want ≤ %v (T-N-008)", store.OfferTTL, maxAllowed)
	}
}

// TestTurnTTLIsShortLived verifies §9.1 T-N-008: TURN credentials must also
// be short-lived to limit credential-theft windows.
func TestTurnTTLIsShortLived(t *testing.T) {
	const maxAllowed = 5 * time.Minute
	if turn.TTL > maxAllowed {
		t.Errorf("turn.TTL = %v; want ≤ %v (T-N-008)", turn.TTL, maxAllowed)
	}
}
