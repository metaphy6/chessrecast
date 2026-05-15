// Package store provides the SQLite-backed persistence layer.
package store

import (
	"database/sql"
	"errors"
	"fmt"
	"sync"
	"time"

	_ "modernc.org/sqlite" // SQLite driver
)

// ErrReadOnly is returned when the store is in degraded read-only mode.
var ErrReadOnly = errors.New("store: read-only mode (primary unavailable)")

// DB wraps a SQLite database and tracks whether it is in read-only (degraded) mode.
type DB struct {
	db       *sql.DB
	path     string
	readOnly bool
	mu       sync.RWMutex
}

// Open opens (or creates) the SQLite database at path with WAL mode enabled.
func Open(path string) (*DB, error) {
	db, err := sql.Open("sqlite", path+"?_journal_mode=WAL&_foreign_keys=on")
	if err != nil {
		return nil, fmt.Errorf("store.Open: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("store.Open ping: %w", err)
	}
	return &DB{db: db, path: path}, nil
}

// Close closes the underlying database connection.
func (d *DB) Close() error {
	return d.db.Close()
}

// SetReadOnly switches the store into degraded read-only mode.
func (d *DB) SetReadOnly(ro bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	d.readOnly = ro
}

// IsReadOnly reports whether the store is in read-only mode.
func (d *DB) IsReadOnly() bool {
	d.mu.RLock()
	defer d.mu.RUnlock()
	return d.readOnly
}

// ExecWrite executes a write SQL statement, returning ErrReadOnly if the
// store is in degraded read-only mode.
func (d *DB) ExecWrite(query string, args ...any) (sql.Result, error) {
	d.mu.RLock()
	ro := d.readOnly
	d.mu.RUnlock()
	if ro {
		return nil, ErrReadOnly
	}
	return d.db.Exec(query, args...)
}

// QueryRow executes a read query (allowed in both modes).
func (d *DB) QueryRow(query string, args ...any) *sql.Row {
	return d.db.QueryRow(query, args...)
}

// Schema is the canonical DDL for the signaling server database.
const Schema = `
CREATE TABLE IF NOT EXISTS accounts (
    account_pub   TEXT PRIMARY KEY,
    device_pub    TEXT NOT NULL,
    last_seen_ts  INTEGER NOT NULL,
    ip_coarse     TEXT    NOT NULL DEFAULT '',
    wrapped_blob  BLOB
);

CREATE TABLE IF NOT EXISTS offers (
    id            TEXT PRIMARY KEY,
    sender_pub    TEXT NOT NULL,
    recipient_pub TEXT NOT NULL,
    sdp_payload   TEXT NOT NULL,
    created_at    INTEGER NOT NULL,
    expires_at    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS ice_candidates (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT    NOT NULL,
    candidate  TEXT    NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS push_tokens (
    device_pub   TEXT PRIMARY KEY,
    token_enc    BLOB    NOT NULL,
    provider     TEXT    NOT NULL,
    last_seen_ts INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS rebind_audit (
    account_pub TEXT    NOT NULL,
    event_ts    INTEGER NOT NULL,
    event_type  TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS schema_meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
`

// InitSchema applies the schema DDL idempotently.
func InitSchema(db *DB) error {
	_, err := db.db.Exec(Schema)
	return err
}

// OfferTTL is the time-to-live for pending offers.
const OfferTTL = 5 * time.Minute

// PushTokenTTL is the maximum age of a push token before it is auto-purged.
const PushTokenTTL = 30 * 24 * time.Hour

// RebindAuditTTL is the retention period for rebind audit rows.
const RebindAuditTTL = 90 * 24 * time.Hour

// PurgeExpired removes rows that have exceeded their TTL.
// Returns counts of purged offers, push tokens, and rebind audit rows.
func PurgeExpired(db *DB) (offers, tokens, audit int64, err error) {
	now := time.Now().Unix()

	res, e := db.ExecWrite("DELETE FROM offers WHERE expires_at <= ?", now)
	if e != nil {
		return 0, 0, 0, fmt.Errorf("purge offers: %w", e)
	}
	offers, _ = res.RowsAffected()

	cutoffTokens := time.Now().Add(-PushTokenTTL).Unix()
	res, e = db.ExecWrite("DELETE FROM push_tokens WHERE last_seen_ts <= ?", cutoffTokens)
	if e != nil {
		return offers, 0, 0, fmt.Errorf("purge push_tokens: %w", e)
	}
	tokens, _ = res.RowsAffected()

	cutoffAudit := time.Now().Add(-RebindAuditTTL).Unix()
	res, e = db.ExecWrite("DELETE FROM rebind_audit WHERE event_ts <= ?", cutoffAudit)
	if e != nil {
		return offers, tokens, 0, fmt.Errorf("purge rebind_audit: %w", e)
	}
	audit, _ = res.RowsAffected()
	return
}
