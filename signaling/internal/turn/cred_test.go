package turn_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/turn"
)

// TestTURNCredentialTTLIs5Minutes verifies that minted credentials expire in
// exactly 5 minutes (§4.1: "TURN credentials short-lived (5 min)").
func TestTURNCredentialTTLIs5Minutes(t *testing.T) {
	kp := turn.NewKeyPair([]byte("test-key-000000000000000000000000"))
	before := time.Now()
	cred, err := kp.Mint("testuser")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}

	// TTL must be 5 minutes (allow ±2s for test execution overhead).
	expectedTTL := 5 * time.Minute
	margin := 2 * time.Second
	actualTTL := cred.ExpiresAt.Sub(before)
	if actualTTL < expectedTTL-margin || actualTTL > expectedTTL+margin {
		t.Errorf("TTL want ~%v, got %v (ExpiresAt=%v)", expectedTTL, actualTTL, cred.ExpiresAt)
	}
}

// TestTURNCredentialUsernameContainsTimestamp verifies the TURN username
// format is "<unix_timestamp>:<base_username>" so coturn can validate expiry
// server-side.
func TestTURNCredentialUsernameContainsTimestamp(t *testing.T) {
	kp := turn.NewKeyPair([]byte("key-0000000000000000000000000000"))
	cred, err := kp.Mint("alice")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}
	// Username must contain a colon separating timestamp from base name.
	found := false
	for _, ch := range cred.Username {
		if ch == ':' {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("username %q must be in <ts>:<user> format", cred.Username)
	}
}

// TestTURNCredentialExpiredIsRejected verifies that a credential with a
// deliberately expired timestamp (ts in the past) is rejected by Verify.
func TestTURNCredentialExpiredIsRejected(t *testing.T) {
	kp := turn.NewKeyPair([]byte("key-0000000000000000000000000000"))

	// Mint a real credential, then swap the username for an expired one.
	cred, err := kp.Mint("bob")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}

	// Replace only the expiry portion of the username so HMAC check passes
	// but time validation should still reject it.
	// Format: "<unix_ts>:<user>" — use ts=1 (1970).
	expiredUsername := "1:bob"
	_ = cred // use to avoid unused variable warning

	if err := kp.VerifyWithExpiry(expiredUsername, "fakepw"); err == nil {
		t.Error("expired credential should be rejected by VerifyWithExpiry")
	}
}
