package invites

import (
	"testing"
	"time"
)

var testSecret = []byte("test-hmac-secret-at-least-32-bytes-ok")
var testPubkey = make([]byte, 32)

func init() {
	for i := range testPubkey {
		testPubkey[i] = byte(i)
	}
}

func newSvc() *Service { return New(testSecret) }

func TestGenerateAndRedeem(t *testing.T) {
	svc := newSvc()
	tok, err := svc.Generate(testPubkey, DefaultTTL)
	if err != nil {
		t.Fatal(err)
	}
	pk, err := svc.Redeem(tok)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	for i, b := range pk {
		if b != testPubkey[i] {
			t.Fatalf("pubkey mismatch at index %d: got %d want %d", i, b, testPubkey[i])
		}
	}
}

func TestRedeemReplayed(t *testing.T) {
	svc := newSvc()
	tok, _ := svc.Generate(testPubkey, DefaultTTL)
	_, err := svc.Redeem(tok)
	if err != nil {
		t.Fatalf("first redeem failed: %v", err)
	}
	_, err = svc.Redeem(tok)
	if err != ErrInviteLinkReplayed {
		t.Fatalf("expected INVITE_LINK_REPLAYED, got %v", err)
	}
}

func TestRedeemExpired(t *testing.T) {
	svc := newSvc()
	// Generate a token that expires in the past.
	tok, _ := svc.Generate(testPubkey, -time.Second)
	_, err := svc.Redeem(tok)
	if err != ErrInviteLinkExpired {
		t.Fatalf("expected INVITE_LINK_EXPIRED, got %v", err)
	}
}

func TestRedeemInvalidToken(t *testing.T) {
	svc := newSvc()
	_, err := svc.Redeem("not-a-valid-token")
	if err != ErrInviteLinkInvalid {
		t.Fatalf("expected INVITE_LINK_INVALID, got %v", err)
	}
}

func TestRedeemTamperedMAC(t *testing.T) {
	svc := newSvc()
	tok, _ := svc.Generate(testPubkey, DefaultTTL)
	// Corrupt the last character.
	runes := []rune(tok)
	runes[len(runes)-1] ^= 0x01
	tampered := string(runes)
	_, err := svc.Redeem(tampered)
	if err != ErrInviteLinkInvalid {
		t.Fatalf("expected INVITE_LINK_INVALID for tampered token, got %v", err)
	}
}

func TestGenerateWrongPubkeyLen(t *testing.T) {
	svc := newSvc()
	_, err := svc.Generate([]byte("short"), DefaultTTL)
	if err == nil {
		t.Fatal("expected error for short pubkey")
	}
}

func TestMultipleTokensSameKey(t *testing.T) {
	svc := newSvc()
	tok1, _ := svc.Generate(testPubkey, DefaultTTL)
	tok2, _ := svc.Generate(testPubkey, DefaultTTL)
	if tok1 == tok2 {
		t.Fatal("tokens should differ due to random nonce")
	}
	// Both should redeem successfully (different nonces).
	if _, err := svc.Redeem(tok1); err != nil {
		t.Fatalf("tok1 redeem failed: %v", err)
	}
	if _, err := svc.Redeem(tok2); err != nil {
		t.Fatalf("tok2 redeem failed: %v", err)
	}
}
