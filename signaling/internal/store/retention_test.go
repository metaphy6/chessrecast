package store_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/store"
)

// TestRetentionOffers verifies that expired offers are purged.
func TestRetentionOffers(t *testing.T) {
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()
	if err := store.InitSchema(db); err != nil {
		t.Fatalf("init schema: %v", err)
	}

	now := time.Now()
	// Insert an expired offer (expires 10 min ago).
	expired := now.Add(-10 * time.Minute).Unix()
	_, err = db.ExecWrite(`INSERT INTO offers (id, sender_pub, recipient_pub, sdp_payload, created_at, expires_at)
		VALUES (?, ?, ?, ?, ?, ?)`,
		"offer-1", "pub-a", "pub-b", "v=0", expired-300, expired)
	if err != nil {
		t.Fatalf("insert expired offer: %v", err)
	}
	// Insert a live offer (expires 2 min from now).
	live := now.Add(2 * time.Minute).Unix()
	_, err = db.ExecWrite(`INSERT INTO offers (id, sender_pub, recipient_pub, sdp_payload, created_at, expires_at)
		VALUES (?, ?, ?, ?, ?, ?)`,
		"offer-2", "pub-a", "pub-c", "v=0", now.Unix(), live)
	if err != nil {
		t.Fatalf("insert live offer: %v", err)
	}

	offers, _, _, err := store.PurgeExpired(db)
	if err != nil {
		t.Fatalf("PurgeExpired: %v", err)
	}
	if offers != 1 {
		t.Fatalf("expected 1 expired offer purged, got %d", offers)
	}

	// Confirm live offer still present.
	var count int
	_ = db.QueryRow("SELECT COUNT(*) FROM offers WHERE id = 'offer-2'").Scan(&count)
	if count != 1 {
		t.Fatal("live offer was incorrectly purged")
	}
}

// TestRetentionPushTokens verifies that stale push tokens are purged after 30 days.
func TestRetentionPushTokens(t *testing.T) {
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()
	if err := store.InitSchema(db); err != nil {
		t.Fatalf("init schema: %v", err)
	}

	old := time.Now().Add(-31 * 24 * time.Hour).Unix()
	_, err = db.ExecWrite(`INSERT INTO push_tokens (device_pub, token_enc, provider, last_seen_ts)
		VALUES (?, ?, ?, ?)`, "dev-old", []byte("enc"), "apns", old)
	if err != nil {
		t.Fatalf("insert old token: %v", err)
	}
	_, err = db.ExecWrite(`INSERT INTO push_tokens (device_pub, token_enc, provider, last_seen_ts)
		VALUES (?, ?, ?, ?)`, "dev-new", []byte("enc"), "apns", time.Now().Unix())
	if err != nil {
		t.Fatalf("insert new token: %v", err)
	}

	_, tokens, _, err := store.PurgeExpired(db)
	if err != nil {
		t.Fatalf("PurgeExpired: %v", err)
	}
	if tokens != 1 {
		t.Fatalf("expected 1 stale token purged, got %d", tokens)
	}
}

// TestRetentionRebindAudit verifies that rebind audit rows older than 90 days are purged.
func TestRetentionRebindAudit(t *testing.T) {
	db, err := store.Open(":memory:")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	defer db.Close()
	if err := store.InitSchema(db); err != nil {
		t.Fatalf("init schema: %v", err)
	}

	old := time.Now().Add(-91 * 24 * time.Hour).Unix()
	_, err = db.ExecWrite(`INSERT INTO rebind_audit (account_pub, event_ts, event_type) VALUES (?, ?, ?)`,
		"pub-x", old, "rebind")
	if err != nil {
		t.Fatalf("insert old audit: %v", err)
	}
	_, err = db.ExecWrite(`INSERT INTO rebind_audit (account_pub, event_ts, event_type) VALUES (?, ?, ?)`,
		"pub-y", time.Now().Unix(), "rebind")
	if err != nil {
		t.Fatalf("insert new audit: %v", err)
	}

	_, _, audit, err := store.PurgeExpired(db)
	if err != nil {
		t.Fatalf("PurgeExpired: %v", err)
	}
	if audit != 1 {
		t.Fatalf("expected 1 old audit row purged, got %d", audit)
	}
}
