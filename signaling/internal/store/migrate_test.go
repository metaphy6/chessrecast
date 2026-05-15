package store_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/store"
)

// TestMigrateUp verifies that the initial migration applies cleanly to a fresh database.
func TestMigrateUp(t *testing.T) {
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()

	if err := store.InitSchema(db); err != nil {
		t.Fatalf("InitSchema: %v", err)
	}
	// Idempotent: applying twice must not fail.
	if err := store.InitSchema(db); err != nil {
		t.Fatalf("InitSchema (idempotent): %v", err)
	}
}

// TestMigrateIrreversible verifies that all down.sql files contain the
// "down_migration_blocked: true" marker, enforcing the forward-only policy.
func TestMigrateIrreversible(t *testing.T) {
	downFiles := []string{
		"migrations/000001_initial_schema.down.sql",
	}
	for _, path := range downFiles {
		data, err := store.MigrationFile(path)
		if err != nil {
			t.Fatalf("read %s: %v", path, err)
		}
		const marker = "down_migration_blocked: true"
		if !containsString(data, marker) {
			t.Errorf("down migration %s is missing required marker %q", path, marker)
		}
	}
}

func containsString(data []byte, s string) bool {
	if len(s) == 0 {
		return true
	}
	for i := 0; i <= len(data)-len(s); i++ {
		if string(data[i:i+len(s)]) == s {
			return true
		}
	}
	return false
}
