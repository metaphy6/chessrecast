package store_test

import (
	"errors"
	"testing"

	"github.com/chessrecast/signaling/internal/store"
)

// TestHADegradedReadsSucceed verifies that read operations succeed in read-only mode.
func TestHADegradedReadsSucceed(t *testing.T) {
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()
	if err := store.InitSchema(db); err != nil {
		t.Fatalf("init schema: %v", err)
	}

	db.SetReadOnly(true)

	// Read (SELECT) must succeed even in read-only mode.
	var count int
	if err := db.QueryRow("SELECT COUNT(*) FROM accounts").Scan(&count); err != nil {
		t.Fatalf("read in RO mode failed: %v", err)
	}
}

// TestHADegradedWritesRejected verifies that write operations return ErrReadOnly in degraded mode.
func TestHADegradedWritesRejected(t *testing.T) {
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()
	if err := store.InitSchema(db); err != nil {
		t.Fatalf("init schema: %v", err)
	}

	db.SetReadOnly(true)

	_, err = db.ExecWrite(
		`INSERT INTO accounts (account_pub, device_pub, last_seen_ts) VALUES (?, ?, ?)`,
		"pub", "dev", 0,
	)
	if !errors.Is(err, store.ErrReadOnly) {
		t.Fatalf("expected ErrReadOnly, got %v", err)
	}
}

// TestHAFailoverRestoresWrites verifies that after promoting from standby (read-only→writable),
// writes succeed again.
func TestHAFailoverRestoresWrites(t *testing.T) {
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()
	if err := store.InitSchema(db); err != nil {
		t.Fatalf("init schema: %v", err)
	}

	// Simulate primary failure → standby enters read-only.
	db.SetReadOnly(true)

	_, errRO := db.ExecWrite(
		`INSERT INTO accounts (account_pub, device_pub, last_seen_ts) VALUES (?, ?, ?)`,
		"pub", "dev", 0,
	)
	if !errors.Is(errRO, store.ErrReadOnly) {
		t.Fatalf("expected ErrReadOnly, got %v", errRO)
	}

	// Simulate promotion: standby becomes primary.
	db.SetReadOnly(false)

	_, errRW := db.ExecWrite(
		`INSERT INTO accounts (account_pub, device_pub, last_seen_ts) VALUES (?, ?, ?)`,
		"pub", "dev", 0,
	)
	if errRW != nil {
		t.Fatalf("write after promotion failed: %v", errRW)
	}
}
