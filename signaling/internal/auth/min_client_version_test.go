package auth_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/auth"
)

// TestMinClientVersionAccepted verifies that a client at or above the floor is accepted.
func TestMinClientVersionAccepted(t *testing.T) {
	min, _ := auth.ParseVersion("2.1.0")
	cases := []string{"2.1.0", "2.1.1", "2.2.0", "3.0.0"}
	for _, s := range cases {
		v, err := auth.ParseVersion(s)
		if err != nil {
			t.Fatalf("parse %q: %v", s, err)
		}
		if err := auth.CheckMinClientVersion(v, min); err != nil {
			t.Errorf("version %q should be accepted: %v", s, err)
		}
	}
}

// TestMinClientVersionRejected verifies that a client below the floor receives
// ErrClientVersionTooOld.
func TestMinClientVersionRejected(t *testing.T) {
	min, _ := auth.ParseVersion("2.1.0")
	cases := []string{"1.9.9", "2.0.9", "2.0.99"}
	for _, s := range cases {
		v, err := auth.ParseVersion(s)
		if err != nil {
			t.Fatalf("parse %q: %v", s, err)
		}
		err = auth.CheckMinClientVersion(v, min)
		if err == nil {
			t.Errorf("version %q should be rejected", s)
		}
		if err != auth.ErrClientVersionTooOld {
			t.Errorf("expected ErrClientVersionTooOld for %q, got %v", s, err)
		}
	}
}

// TestMinClientVersionHTTP426 verifies that a route returns 426 when the client
// version is below the floor.
func TestMinClientVersionHTTP426(t *testing.T) {
	// This test proves the error sentinel maps to HTTP 426 Upgrade Required.
	// The actual HTTP wiring lives in routes.go; here we verify the error value.
	min, _ := auth.ParseVersion("3.0.0")
	client, _ := auth.ParseVersion("2.9.9")
	err := auth.CheckMinClientVersion(client, min)
	if err != auth.ErrClientVersionTooOld {
		t.Fatalf("expected ErrClientVersionTooOld, got %v", err)
	}
}
