// Package dsar provides Data Subject Access Request (DSAR) functionality.
//
// It implements the access and deletion rights under GDPR/CCPA:
//   - ExportForKey returns coarse last_seen, push-token hash, and audit rows.
//   - DeleteForKey wipes all rows for the given account pubkey.
//   - PruneOldAuditRows removes audit rows older than the given retention period.
//
// Note: this package operates only on the SQLite store. Any litestream
// snapshots must be handled by the operator according to the runbook in
// docs/P2P_RECOVERY_RUNBOOK.md (snapshot TTL ≤ 30 days per DATA_RESIDENCY.md).
package dsar

import (
	"fmt"
	"time"

	"github.com/chessrecast/signaling/internal/store"
)

// AuditRow is a single DSAR audit log entry.
type AuditRow struct {
	EventType  string
	OccurredAt time.Time
}

// ExportResult holds the data returned for a single account pubkey.
type ExportResult struct {
	PubKey        string
	PushTokenHash string
	LastSeen      time.Time
	AuditRows     []AuditRow
}

// Migrate ensures the DSAR-owned tables exist.
// Idempotent — safe to call on every startup.
func Migrate(db *store.DB) error {
	sqls := []string{
		`CREATE TABLE IF NOT EXISTS dsar_accounts (
			pubkey          TEXT PRIMARY KEY,
			push_token_hash TEXT NOT NULL DEFAULT '',
			last_seen       DATETIME NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS dsar_audit (
			id          INTEGER PRIMARY KEY AUTOINCREMENT,
			pubkey      TEXT    NOT NULL,
			event_type  TEXT    NOT NULL,
			occurred_at DATETIME NOT NULL,
			FOREIGN KEY (pubkey) REFERENCES dsar_accounts(pubkey) ON DELETE CASCADE
		)`,
		`CREATE INDEX IF NOT EXISTS dsar_audit_pubkey_idx ON dsar_audit(pubkey)`,
		`CREATE INDEX IF NOT EXISTS dsar_audit_occurred_idx ON dsar_audit(occurred_at)`,
	}
	for _, s := range sqls {
		if _, err := db.ExecWrite(s); err != nil {
			return fmt.Errorf("dsar.Migrate: %w", err)
		}
	}
	return nil
}

// UpsertAccount inserts or replaces the account row for pubkey.
func UpsertAccount(db *store.DB, pubkey, pushTokenHash string, lastSeen time.Time) error {
	_, err := db.ExecWrite(
		`INSERT INTO dsar_accounts (pubkey, push_token_hash, last_seen)
		 VALUES (?, ?, ?)
		 ON CONFLICT(pubkey) DO UPDATE SET
		   push_token_hash = excluded.push_token_hash,
		   last_seen       = excluded.last_seen`,
		pubkey, pushTokenHash, lastSeen.UTC().Format(time.RFC3339),
	)
	if err != nil {
		return fmt.Errorf("dsar.UpsertAccount: %w", err)
	}
	return nil
}

// AddAuditRow appends an audit event for pubkey.
func AddAuditRow(db *store.DB, pubkey, eventType string, occurredAt time.Time) error {
	_, err := db.ExecWrite(
		`INSERT INTO dsar_audit (pubkey, event_type, occurred_at) VALUES (?, ?, ?)`,
		pubkey, eventType, occurredAt.UTC().Format(time.RFC3339),
	)
	if err != nil {
		return fmt.Errorf("dsar.AddAuditRow: %w", err)
	}
	return nil
}

// ExportForKey returns the DSAR data for pubkey, or nil if the account does
// not exist.
func ExportForKey(db *store.DB, pubkey string) (*ExportResult, error) {
	var result ExportResult
	result.PubKey = pubkey

	row := db.QueryRow(
		`SELECT push_token_hash, last_seen FROM dsar_accounts WHERE pubkey = ?`,
		pubkey,
	)
	var lastSeenStr string
	if err := row.Scan(&result.PushTokenHash, &lastSeenStr); err != nil {
		// sql.ErrNoRows → account not found.
		return nil, nil //nolint:nilerr // intentional: not found = nil
	}

	t, _ := time.Parse(time.RFC3339, lastSeenStr)
	result.LastSeen = t.UTC()

	rows, err := db.Query(
		`SELECT event_type, occurred_at FROM dsar_audit WHERE pubkey = ? ORDER BY occurred_at`,
		pubkey,
	)
	if err != nil {
		return nil, fmt.Errorf("dsar.ExportForKey audit query: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var ar AuditRow
		var occurredStr string
		if scanErr := rows.Scan(&ar.EventType, &occurredStr); scanErr != nil {
			return nil, fmt.Errorf("dsar.ExportForKey scan: %w", scanErr)
		}
		ot, _ := time.Parse(time.RFC3339, occurredStr)
		ar.OccurredAt = ot.UTC()
		result.AuditRows = append(result.AuditRows, ar)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("dsar.ExportForKey rows: %w", err)
	}

	return &result, nil
}

// DeleteForKey wipes the account and all associated audit rows.
// Litestream snapshots must be handled separately (TTL ≤ 30 days).
func DeleteForKey(db *store.DB, pubkey string) error {
	// ON DELETE CASCADE on dsar_audit removes audit rows automatically.
	_, err := db.ExecWrite(`DELETE FROM dsar_accounts WHERE pubkey = ?`, pubkey)
	if err != nil {
		return fmt.Errorf("dsar.DeleteForKey: %w", err)
	}
	return nil
}

// PruneOldAuditRows deletes audit rows whose occurred_at is older than
// retentionPeriod from now. Intended to be called on a daily schedule.
func PruneOldAuditRows(db *store.DB, retentionPeriod time.Duration) error {
	cutoff := time.Now().UTC().Add(-retentionPeriod).Format(time.RFC3339)
	_, err := db.ExecWrite(`DELETE FROM dsar_audit WHERE occurred_at < ?`, cutoff)
	if err != nil {
		return fmt.Errorf("dsar.PruneOldAuditRows: %w", err)
	}
	return nil
}
