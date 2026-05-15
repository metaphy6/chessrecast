// Package dr contains disaster-recovery proof tests.
// The cold-restore drill simulates litestream cold-restore: copy the .db file,
// apply the schema, and verify row integrity.
package dr_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/chessrecast/signaling/internal/store"
)

// TestColdRestoreDrill simulates a cold restore from a litestream backup:
// 1. Seed a "primary" SQLite database with known rows.
// 2. Copy the database file to a "restore" path (simulating litestream restore).
// 3. Open the restored DB, apply the schema idempotently, and verify row presence.
func TestColdRestoreDrill(t *testing.T) {
	dir := t.TempDir()
	primaryPath := filepath.Join(dir, "primary.db")
	restorePath := filepath.Join(dir, "restored.db")

	// ── Step 1: seed primary ────────────────────────────────────────────────
	primary, err := store.Open(primaryPath)
	if err != nil {
		t.Fatalf("open primary: %v", err)
	}
	if err := store.InitSchema(primary); err != nil {
		t.Fatalf("init schema: %v", err)
	}
	_, err = primary.ExecWrite(
		`INSERT INTO accounts (account_pub, device_pub, last_seen_ts) VALUES (?,?,?)`,
		"test-pub", "test-dev", 1000000,
	)
	if err != nil {
		t.Fatalf("seed: %v", err)
	}
	if err := primary.Close(); err != nil {
		t.Fatalf("close primary: %v", err)
	}

	// ── Step 2: simulate litestream cold restore (file copy) ─────────────────
	data, err := os.ReadFile(primaryPath)
	if err != nil {
		t.Fatalf("read primary db: %v", err)
	}
	if err := os.WriteFile(restorePath, data, 0o600); err != nil {
		t.Fatalf("write restore db: %v", err)
	}

	// ── Step 3: verify restored DB ───────────────────────────────────────────
	restored, err := store.Open(restorePath)
	if err != nil {
		t.Fatalf("open restored: %v", err)
	}
	defer restored.Close()
	// Schema apply is idempotent; must succeed on an already-initialised DB.
	if err := store.InitSchema(restored); err != nil {
		t.Fatalf("init schema on restored: %v", err)
	}

	var count int
	if err := restored.QueryRow("SELECT COUNT(*) FROM accounts WHERE account_pub='test-pub'").Scan(&count); err != nil {
		t.Fatalf("query restored: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected 1 account in restored DB, got %d", count)
	}
}
