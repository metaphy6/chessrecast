package store_test

import (
	"bytes"
	"testing"

	"github.com/chessrecast/signaling/internal/store"
)

// forbiddenColumns lists PII columns that must never appear in the schema.
var forbiddenColumns = []string{
	"email",
	"name",
	"full_ip",
	"phone",
	"dob",
	"raw_push_token",
	"first_name",
	"last_name",
	"birth",
	"password",
}

// TestPIIAudit verifies that the schema does not contain any forbidden PII columns.
func TestPIIAudit(t *testing.T) {
	schemaBytes := []byte(store.Schema)
	for _, col := range forbiddenColumns {
		// Check both "col TEXT" and "col BLOB" and "col INTEGER" patterns.
		for _, suffix := range []string{" TEXT", " BLOB", " INTEGER", "\t"} {
			needle := []byte(col + suffix)
			if bytes.Contains(schemaBytes, needle) {
				t.Errorf("schema contains forbidden PII column: %q (found with suffix %q)", col, suffix)
			}
		}
	}
}

// TestPIIAllowedColumns verifies that the schema contains the correct privacy-preserving columns.
func TestPIIAllowedColumns(t *testing.T) {
	required := []string{
		"account_pub",
		"device_pub",
		"last_seen_ts",
		"ip_coarse",
		"token_enc",
	}
	schemaBytes := []byte(store.Schema)
	for _, col := range required {
		if !bytes.Contains(schemaBytes, []byte(col)) {
			t.Errorf("expected privacy-preserving column %q in schema", col)
		}
	}
}
