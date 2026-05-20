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
	EventType  string    `json:"event_type"`
	OccurredAt time.Time `json:"occurred_at"`
}

// ExportResult holds the data returned for a single account pubkey in
// machine-readable JSON format (v10 §18.3 requirement).
type ExportResult struct {
	PubKey        string     `json:"pubkey"`
	PushTokenHash string     `json:"push_token_hash"`
	LastSeen      time.Time  `json:"last_seen"`
	AuditRows     []AuditRow `json:"audit_rows"`
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

// DeletionRequest is an authenticated deletion request submitted by the
// account holder (§18.5). The Signature field must be set by callers that
// perform full Ed25519 verification; the base unit-test layer verifies
// structural presence only (full crypto integration tested separately).
type DeletionRequest struct {
	// AccountPubkey is the hex-encoded Ed25519 public key of the account.
	AccountPubkey string
	// Signature is the Ed25519 signature over the canonical request bytes.
	// Must be non-empty for HandleDeletionRequest to accept the request.
	Signature []byte
	// Timestamp is the ISO-8601 request timestamp (replay-protection window).
	Timestamp string
}

// HandleDeletionRequest validates and executes a signed account deletion.
//
// Structural validation: AccountPubkey and Signature must be non-empty and
// Timestamp must be parseable.  Full Ed25519 signature verification is
// expected to be performed by the HTTP handler before this function is called.
//
// On success all server-side state for the account is purged:
//   - dsar_accounts row and cascaded dsar_audit rows.
//   - Litestream snapshot TTL enforcement is the operator's responsibility
//     (TTL ≤ 30 days per P2P_RECOVERY_RUNBOOK.md).
//
// Abuse reports filed *against* the account are retained and anonymised by
// the abuse package (§14.3); this function does not touch the abuse tables.
// Abuse reports filed *by* the account must be purged by the caller using the
// abuse package's purge-by-reporter function.
func HandleDeletionRequest(db *store.DB, req DeletionRequest) error {
	if req.AccountPubkey == "" {
		return fmt.Errorf("dsar.HandleDeletionRequest: empty AccountPubkey")
	}
	if len(req.Signature) == 0 {
		return fmt.Errorf("dsar.HandleDeletionRequest: missing Signature")
	}
	if _, err := parseTimestamp(req.Timestamp); err != nil {
		return fmt.Errorf("dsar.HandleDeletionRequest: bad Timestamp: %w", err)
	}
	return DeleteForKey(db, req.AccountPubkey)
}

// parseTimestamp parses an ISO-8601 / RFC3339 timestamp string.
func parseTimestamp(s string) (time.Time, error) {
	if s == "" {
		return time.Time{}, fmt.Errorf("empty timestamp")
	}
	return time.Parse(time.RFC3339, s)
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
