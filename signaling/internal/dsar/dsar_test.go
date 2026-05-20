package dsar_test

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/dsar"
	"github.com/chessrecast/signaling/internal/store"
)

// openTestDB opens an in-memory SQLite database suitable for unit tests.
func openTestDB(t *testing.T) *store.DB {
	t.Helper()
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("openTestDB: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}

// TestDSAR_Export verifies that ExportForKey returns:
//   - coarse last_seen timestamp
//   - push-token hash
//   - audit rows associated with the key
func TestDSAR_Export(t *testing.T) {
	db := openTestDB(t)
	if err := dsar.Migrate(db); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	const pubkey = "aabbccddeeff001122334455"
	tokenHash := hashToken("push-token-abc")
	now := time.Now().UTC().Truncate(time.Hour) // coarse timestamp

	// Seed data.
	if err := dsar.UpsertAccount(db, pubkey, tokenHash, now); err != nil {
		t.Fatalf("UpsertAccount: %v", err)
	}
	if err := dsar.AddAuditRow(db, pubkey, "invite_accepted", time.Now()); err != nil {
		t.Fatalf("AddAuditRow: %v", err)
	}
	if err := dsar.AddAuditRow(db, pubkey, "invite_declined", time.Now()); err != nil {
		t.Fatalf("AddAuditRow: %v", err)
	}

	result, err := dsar.ExportForKey(db, pubkey)
	if err != nil {
		t.Fatalf("ExportForKey: %v", err)
	}

	if result.PushTokenHash != tokenHash {
		t.Errorf("PushTokenHash: got %q, want %q", result.PushTokenHash, tokenHash)
	}
	if !result.LastSeen.Equal(now) {
		t.Errorf("LastSeen: got %v, want %v", result.LastSeen, now)
	}
	if len(result.AuditRows) != 2 {
		t.Errorf("AuditRows: got %d, want 2", len(result.AuditRows))
	}
}

// TestDSAR_Delete verifies that DeleteForKey wipes all rows for the given key.
func TestDSAR_Delete(t *testing.T) {
	db := openTestDB(t)
	if err := dsar.Migrate(db); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	const pubkey = "deadbeef01234567"
	if err := dsar.UpsertAccount(db, pubkey, hashToken("tok"), time.Now()); err != nil {
		t.Fatalf("UpsertAccount: %v", err)
	}
	if err := dsar.AddAuditRow(db, pubkey, "invite_accepted", time.Now()); err != nil {
		t.Fatalf("AddAuditRow: %v", err)
	}

	if err := dsar.DeleteForKey(db, pubkey); err != nil {
		t.Fatalf("DeleteForKey: %v", err)
	}

	result, err := dsar.ExportForKey(db, pubkey)
	if err != nil {
		t.Fatalf("ExportForKey after delete: %v", err)
	}
	if result != nil {
		t.Errorf("expected nil result after deletion, got %+v", result)
	}
}

// TestDSAR_AuditRowRetention verifies that audit rows older than 90 days
// are pruned by PruneOldAuditRows.
func TestDSAR_AuditRowRetention(t *testing.T) {
	db := openTestDB(t)
	if err := dsar.Migrate(db); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	const pubkey = "cafebabe99887766"
	if err := dsar.UpsertAccount(db, pubkey, hashToken("tok2"), time.Now()); err != nil {
		t.Fatalf("UpsertAccount: %v", err)
	}

	old := time.Now().Add(-91 * 24 * time.Hour)
	recent := time.Now().Add(-2 * 24 * time.Hour)

	if err := dsar.AddAuditRow(db, pubkey, "old_event", old); err != nil {
		t.Fatalf("AddAuditRow (old): %v", err)
	}
	if err := dsar.AddAuditRow(db, pubkey, "recent_event", recent); err != nil {
		t.Fatalf("AddAuditRow (recent): %v", err)
	}

	if err := dsar.PruneOldAuditRows(db, 90*24*time.Hour); err != nil {
		t.Fatalf("PruneOldAuditRows: %v", err)
	}

	result, err := dsar.ExportForKey(db, pubkey)
	if err != nil {
		t.Fatalf("ExportForKey: %v", err)
	}
	if len(result.AuditRows) != 1 {
		t.Errorf("AuditRows after prune: got %d, want 1", len(result.AuditRows))
	}
	if result.AuditRows[0].EventType != "recent_event" {
		t.Errorf("wrong surviving row: %q", result.AuditRows[0].EventType)
	}
}

// TestDSAR_Export_MachineReadableJSON verifies §18.3 v10 requirement:
// ExportResult is serialisable to machine-readable JSON with expected keys.
func TestDSAR_Export_MachineReadableJSON(t *testing.T) {
	db := openTestDB(t)
	if err := dsar.Migrate(db); err != nil {
		t.Fatalf("Migrate: %v", err)
	}

	const pubkey = "aabbccddeeff9900"
	tokenHash := hashToken("push-token-json")
	now := time.Now().UTC().Truncate(time.Hour)

	if err := dsar.UpsertAccount(db, pubkey, tokenHash, now); err != nil {
		t.Fatalf("UpsertAccount: %v", err)
	}
	if err := dsar.AddAuditRow(db, pubkey, "game_started", time.Now()); err != nil {
		t.Fatalf("AddAuditRow: %v", err)
	}

	result, err := dsar.ExportForKey(db, pubkey)
	if err != nil {
		t.Fatalf("ExportForKey: %v", err)
	}

	raw, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("json.Marshal(ExportResult): %v", err)
	}

	var m map[string]interface{}
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatalf("json.Unmarshal: %v", err)
	}

	for _, key := range []string{"pubkey", "push_token_hash", "last_seen", "audit_rows"} {
		if _, ok := m[key]; !ok {
			t.Errorf("JSON response missing key %q", key)
		}
	}

	rows, ok := m["audit_rows"].([]interface{})
	if !ok || len(rows) != 1 {
		t.Errorf("expected 1 audit_row, got %v", m["audit_rows"])
	}
}
