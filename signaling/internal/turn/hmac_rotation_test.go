package turn_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/turn"
)

// TestTURNHMACRotationCredentialValidUnderBothKeys verifies that a credential
// minted under the old key is still accepted for TTL after rotation (dual-key
// overlap window).
func TestTURNHMACRotationCredentialValidUnderBothKeys(t *testing.T) {
	oldKey := []byte("old-hmac-key-0000000000000000000")
	newKey := []byte("new-hmac-key-0000000000000000000")

	kp := turn.NewKeyPair(oldKey)

	// Mint a credential with the old key.
	cred, err := kp.Mint("alice")
	if err != nil {
		t.Fatalf("Mint: %v", err)
	}

	// Rotate to a new key.
	kp.Rotate(newKey)

	// Credential minted under old key should still verify (overlap window).
	if err := kp.Verify(cred.Username, cred.Password); err != nil {
		t.Fatalf("credential minted under old key should be valid after rotation: %v", err)
	}
}

// TestTURNHMACNewCredentialAfterRotation verifies that a credential minted after
// rotation verifies under the current (new) key.
func TestTURNHMACNewCredentialAfterRotation(t *testing.T) {
	oldKey := []byte("old-hmac-key-0000000000000000000")
	newKey := []byte("new-hmac-key-0000000000000000000")

	kp := turn.NewKeyPair(oldKey)
	kp.Rotate(newKey)

	cred, err := kp.Mint("bob")
	if err != nil {
		t.Fatalf("Mint after rotation: %v", err)
	}
	if err := kp.Verify(cred.Username, cred.Password); err != nil {
		t.Fatalf("new credential should verify after rotation: %v", err)
	}
}

// TestTURNHMACInvalidCredentialRejected verifies that a tampered password is rejected.
func TestTURNHMACInvalidCredentialRejected(t *testing.T) {
	kp := turn.NewKeyPair([]byte("test-key-00000000000000000000000"))
	cred, _ := kp.Mint("charlie")
	if err := kp.Verify(cred.Username, "tampered-password"); err == nil {
		t.Fatal("tampered credential should be rejected")
	}
}

// TestTURNHMACRotatedAtUpdated verifies that Rotate updates the RotatedAt timestamp.
func TestTURNHMACRotatedAtUpdated(t *testing.T) {
	kp := turn.NewKeyPair([]byte("key1"))
	before := kp.RotatedAt()
	time.Sleep(2 * time.Millisecond)
	kp.Rotate([]byte("key2"))
	after := kp.RotatedAt()
	if !after.After(before) {
		t.Fatal("RotatedAt should advance after Rotate")
	}
}
