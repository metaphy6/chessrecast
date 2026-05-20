// Proof test for roadmap §18.5 — Right to Erasure (delete-my-data).
//
// Tests the HandleDeletionRequest flow:
//  1. Valid signed deletion request purges all server-side state.
//  2. Missing Signature is rejected before any DB write.
//  3. Empty pubkey is rejected.
//  4. Bad Timestamp is rejected.
//  5. Deletion is idempotent (re-deletion returns nil, not an error).
//  6. After deletion ExportForKey returns nil (account is gone).
package dsar_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/dsar"
	"github.com/chessrecast/signaling/internal/store"
)

// openTestDBForDelete opens an in-memory SQLite DB for delete-path tests.
func openTestDBForDelete(t *testing.T) *store.DB {
	t.Helper()
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("openTestDBForDelete: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func seedAccount(t *testing.T, db *store.DB, pubkey string) {
	t.Helper()
	if err := dsar.Migrate(db); err != nil {
		t.Fatalf("Migrate: %v", err)
	}
	if err := dsar.UpsertAccount(db, pubkey, "tok-hash", time.Now()); err != nil {
		t.Fatalf("UpsertAccount(%q): %v", pubkey, err)
	}
	if err := dsar.AddAuditRow(db, pubkey, "invite_sent", time.Now()); err != nil {
		t.Fatalf("AddAuditRow: %v", err)
	}
}

func validReq(pubkey string) dsar.DeletionRequest {
	return dsar.DeletionRequest{
		AccountPubkey: pubkey,
		Signature:     []byte("mock-ed25519-sig"), // full crypto tested separately
		Timestamp:     time.Now().UTC().Format(time.RFC3339),
	}
}

// TestHandleDeletionRequest_PurgesAccount verifies that a valid deletion
// request removes the account and all associated audit rows.
func TestHandleDeletionRequest_PurgesAccount(t *testing.T) {
	db := openTestDBForDelete(t)
	const pubkey = "aabb1122ccdd3344"
	seedAccount(t, db, pubkey)

	if err := dsar.HandleDeletionRequest(db, validReq(pubkey)); err != nil {
		t.Fatalf("HandleDeletionRequest: %v", err)
	}

	result, err := dsar.ExportForKey(db, pubkey)
	if err != nil {
		t.Fatalf("ExportForKey after deletion: %v", err)
	}
	if result != nil {
		t.Errorf("expected nil after deletion, got %+v", result)
	}
}

// TestHandleDeletionRequest_RejectsEmptySignature verifies that a request
// without a Signature is rejected before any DB mutation.
func TestHandleDeletionRequest_RejectsEmptySignature(t *testing.T) {
	db := openTestDBForDelete(t)
	const pubkey = "aabb1122ccdd5566"
	seedAccount(t, db, pubkey)

	req := validReq(pubkey)
	req.Signature = nil

	if err := dsar.HandleDeletionRequest(db, req); err == nil {
		t.Error("expected error for missing Signature, got nil")
	}

	// Account must still exist.
	result, err := dsar.ExportForKey(db, pubkey)
	if err != nil {
		t.Fatalf("ExportForKey: %v", err)
	}
	if result == nil {
		t.Error("account was deleted despite rejected request")
	}
}

// TestHandleDeletionRequest_RejectsEmptyPubkey verifies that an empty pubkey
// is rejected without touching the DB.
func TestHandleDeletionRequest_RejectsEmptyPubkey(t *testing.T) {
	db := openTestDBForDelete(t)
	if err := dsar.Migrate(db); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	req := dsar.DeletionRequest{
		AccountPubkey: "",
		Signature:     []byte("sig"),
		Timestamp:     time.Now().UTC().Format(time.RFC3339),
	}

	if err := dsar.HandleDeletionRequest(db, req); err == nil {
		t.Error("expected error for empty AccountPubkey, got nil")
	}
}

// TestHandleDeletionRequest_RejectsBadTimestamp verifies that a request with
// an unparseable Timestamp is rejected.
func TestHandleDeletionRequest_RejectsBadTimestamp(t *testing.T) {
	db := openTestDBForDelete(t)
	const pubkey = "aabb1122ccdd7788"
	seedAccount(t, db, pubkey)

	req := validReq(pubkey)
	req.Timestamp = "not-a-timestamp"

	if err := dsar.HandleDeletionRequest(db, req); err == nil {
		t.Error("expected error for bad Timestamp, got nil")
	}
}

// TestHandleDeletionRequest_Idempotent verifies that deleting an account that
// no longer exists returns nil (idempotent).
func TestHandleDeletionRequest_Idempotent(t *testing.T) {
	db := openTestDBForDelete(t)
	const pubkey = "aabb1122ccdd9900"
	seedAccount(t, db, pubkey)

	// First deletion.
	if err := dsar.HandleDeletionRequest(db, validReq(pubkey)); err != nil {
		t.Fatalf("first HandleDeletionRequest: %v", err)
	}

	// Second deletion — must not error.
	if err := dsar.HandleDeletionRequest(db, validReq(pubkey)); err != nil {
		t.Errorf("second (idempotent) HandleDeletionRequest: %v", err)
	}
}
