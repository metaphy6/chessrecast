// spectator_chat_report_test.go — §7.9.7 server-side proof test
package abuse_test

import (
	"crypto/rand"
	"testing"

	"github.com/chessrecast/signaling/internal/abuse"
)

// TestSpectatorChatReportFiled verifies a valid report is queued.
func TestSpectatorChatReportFiled(t *testing.T) {
	r := abuse.NewSpectatorChatReporter()
	hash := abuse.ComputeMessageHash([]byte("some ciphertext"))
	p := &abuse.SpectatorChatReportPayload{
		ReporterPubKeyHex: "aabb",
		TargetPubKeyHex:   "ccdd",
		GameID:            "g1",
		MessageHash:       hash,
	}
	if err := r.File(p); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if r.QueueDepth() != 1 {
		t.Fatalf("queue depth = %d, want 1", r.QueueDepth())
	}
}

// TestSpectatorChatReportRateLimit verifies 5/day cap (§7.9.7).
func TestSpectatorChatReportRateLimit(t *testing.T) {
	r := abuse.NewSpectatorChatReporter()
	reporter := "reporter_aabb"
	p := &abuse.SpectatorChatReportPayload{
		ReporterPubKeyHex: reporter,
		TargetPubKeyHex:   "ccdd",
		GameID:            "g2",
	}
	for i := 0; i < 5; i++ {
		if err := r.File(p); err != nil {
			t.Fatalf("report %d: unexpected error: %v", i, err)
		}
	}
	if err := r.File(p); err == nil {
		t.Fatal("expected rate-limit error on 6th report")
	}
	if r.ReportsToday(reporter) != 5 {
		t.Fatalf("reports today = %d, want 5", r.ReportsToday(reporter))
	}
}

// TestSpectatorChatReportHash verifies ComputeMessageHash is deterministic.
func TestSpectatorChatReportHash(t *testing.T) {
	msg := make([]byte, 64)
	rand.Read(msg) //nolint:errcheck
	h1 := abuse.ComputeMessageHash(msg)
	h2 := abuse.ComputeMessageHash(msg)
	if h1 != h2 {
		t.Fatal("hash not deterministic")
	}
}
