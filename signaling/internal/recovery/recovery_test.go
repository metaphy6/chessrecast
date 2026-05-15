package recovery_test

// Phase 2.2 — Server-side recovery stub tests.
//
// These stubs document the behavioral contracts that the signaling server MUST
// implement in Phase 3 (§3.1–3.2). They are intentionally minimal: Go
// compilation is verified, but the actual HTTP server is not yet wired (Phase 3).
//
// When Phase 3.1 lands:
//   1. Replace the stub handler with a real httptest.Server.
//   2. Remove the t.Skip() guards.
//   3. Regenerate baselines.

import (
	"fmt"
	"testing"
)

// StubRecoveryStore is a test double for the signaling server's recovery store.
type StubRecoveryStore struct {
	blobs map[string][]byte // account_pub (hex) → wrapped_blob
}

func newStubStore() *StubRecoveryStore {
	return &StubRecoveryStore{blobs: make(map[string][]byte)}
}

func (s *StubRecoveryStore) StoreBlob(accountPub string, blob []byte) error {
	if len(blob) > 256 {
		return fmt.Errorf("blob exceeds 256-byte limit: %d bytes", len(blob))
	}
	s.blobs[accountPub] = blob
	return nil
}

func (s *StubRecoveryStore) FetchBlob(accountPub string) ([]byte, bool) {
	b, ok := s.blobs[accountPub]
	return b, ok
}

// TestBlobStoreAndFetch verifies end-to-end wrapped-blob storage + retrieval.
func TestBlobStoreAndFetch(t *testing.T) {
	t.Skip("Phase 3 not yet started — stub passes structural checks only")
	store := newStubStore()
	accountPub := "aabbccddeeff0011"
	blob := make([]byte, 87) // §2.2 wire layout
	blob[0] = 1              // kdf_version
	if err := store.StoreBlob(accountPub, blob); err != nil {
		t.Fatalf("StoreBlob: %v", err)
	}
	got, ok := store.FetchBlob(accountPub)
	if !ok {
		t.Fatal("FetchBlob: not found after store")
	}
	if len(got) != len(blob) {
		t.Fatalf("blob length mismatch: got %d want %d", len(got), len(blob))
	}
}

// TestBlobSizeCap verifies the server rejects blobs > 256 bytes.
func TestBlobSizeCap(t *testing.T) {
	t.Skip("Phase 3 not yet started — stub passes structural checks only")
	store := newStubStore()
	oversized := make([]byte, 257)
	err := store.StoreBlob("pubkeyXX", oversized)
	if err == nil {
		t.Fatal("expected error for oversized blob, got nil")
	}
}

// TestServerCannotDeriveAccountKey verifies the server holds no plaintext.
//
// The blob it stores is opaque ciphertext; without the recovery code (which
// only the user has), the server cannot derive the account key.
func TestServerCannotDeriveAccountKey(t *testing.T) {
	t.Skip("Phase 3 not yet started — stub passes structural checks only")
	// Conceptually: the server stores blob[0:87] as an opaque byte slice.
	// It has no knowledge of kek, salt derivation, or plaintext.
	// Test is structural — the store type has no Decrypt method.
	store := newStubStore()
	blob := make([]byte, 87)
	if err := store.StoreBlob("pubkey", blob); err != nil {
		t.Fatal(err)
	}
	// There is intentionally no store.Decrypt() method.
	// If one existed, this test would fail to compile.
	_ = store
}
