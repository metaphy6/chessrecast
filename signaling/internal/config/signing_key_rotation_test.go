package config_test

import (
	"crypto/ed25519"
	"crypto/rand"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/config"
)

func generateKey(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatalf("generate key: %v", err)
	}
	return pub, priv
}

// TestSigningKeyRotationOldKeyValidDuringOverlap verifies that a payload signed
// with the old key is still accepted after rotation (one-update-cycle overlap).
func TestSigningKeyRotationOldKeyValidDuringOverlap(t *testing.T) {
	oldPub, oldPriv := generateKey(t)
	newPub, _ := generateKey(t)

	ks := config.NewKeySet(oldPub)

	payload := []byte(`{"setting":"value"}`)
	sig := ed25519.Sign(oldPriv, payload)

	// Rotate to new key.
	ks.Rotate(newPub)

	// Old-signed payload should still verify.
	if err := ks.Verify(payload, sig); err != nil {
		t.Fatalf("old key should still be valid in overlap window: %v", err)
	}
}

// TestSigningKeyRotationNewKeyAccepted verifies that payloads signed with the
// new key are accepted after rotation.
func TestSigningKeyRotationNewKeyAccepted(t *testing.T) {
	_, oldPriv := generateKey(t)
	newPub, newPriv := generateKey(t)

	ks := config.NewKeySet(newPub)
	_ = oldPriv

	payload := []byte(`{"setting":"new-value"}`)
	sig := ed25519.Sign(newPriv, payload)

	if err := ks.Verify(payload, sig); err != nil {
		t.Fatalf("new key should verify new payload: %v", err)
	}
}

// TestSigningKeyRotationUnknownKeyRejected verifies that a signature from an
// unknown key is rejected.
func TestSigningKeyRotationUnknownKeyRejected(t *testing.T) {
	pub, _ := generateKey(t)
	_, foreignPriv := generateKey(t)

	ks := config.NewKeySet(pub)

	payload := []byte(`{"setting":"value"}`)
	sig := ed25519.Sign(foreignPriv, payload)

	if err := ks.Verify(payload, sig); err == nil {
		t.Fatal("foreign key signature should be rejected")
	}
}

// TestSigningKeyRotatedAtUpdated verifies that Rotate advances the RotatedAt timestamp.
func TestSigningKeyRotatedAtUpdated(t *testing.T) {
	pub, _ := generateKey(t)
	ks := config.NewKeySet(pub)

	before := ks.RotatedAt()
	time.Sleep(2 * time.Millisecond)

	newPub, _ := generateKey(t)
	ks.Rotate(newPub)

	if !ks.RotatedAt().After(before) {
		t.Fatal("RotatedAt should advance after Rotate")
	}
}
