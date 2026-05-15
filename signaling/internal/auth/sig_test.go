package auth_test

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/auth"
)

func TestValidSignature(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	v := auth.NewVerifier()

	body := []byte(`{"hello":"world"}`)
	sum := sha256.Sum256(body)
	claims := auth.RequestClaims{
		Method:  "POST",
		Path:    "/v1/accounts/register",
		Ts:      time.Now(),
		BodySHA: sum,
	}
	sig := auth.Sign(priv, claims)
	if err := v.Verify(pub, sig, claims); err != nil {
		t.Fatalf("valid signature rejected: %v", err)
	}
}

func TestReplayAttack(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	v := auth.NewVerifier()

	body := []byte(`{"hello":"world"}`)
	sum := sha256.Sum256(body)
	claims := auth.RequestClaims{
		Method:  "POST",
		Path:    "/v1/accounts/register",
		Ts:      time.Now(),
		BodySHA: sum,
	}
	sig := auth.Sign(priv, claims)

	// First use: should succeed.
	if err := v.Verify(pub, sig, claims); err != nil {
		t.Fatalf("first verify failed: %v", err)
	}
	// Second use of same sig: must be rejected.
	if err := v.Verify(pub, sig, claims); err == nil {
		t.Fatal("replay not detected: second verify should have failed")
	}
}

func TestExpiredTimestamp(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	v := auth.NewVerifier()

	body := []byte(`{}`)
	sum := sha256.Sum256(body)
	claims := auth.RequestClaims{
		Method:  "GET",
		Path:    "/v1/health",
		Ts:      time.Now().Add(-90 * time.Second), // 90s ago — outside ±60s window
		BodySHA: sum,
	}
	sig := auth.Sign(priv, claims)
	if err := v.Verify(pub, sig, claims); err == nil {
		t.Fatal("expired timestamp accepted")
	}
}

func TestFutureTimestamp(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	v := auth.NewVerifier()

	body := []byte(`{}`)
	sum := sha256.Sum256(body)
	claims := auth.RequestClaims{
		Method:  "GET",
		Path:    "/v1/health",
		Ts:      time.Now().Add(90 * time.Second), // 90s in the future
		BodySHA: sum,
	}
	sig := auth.Sign(priv, claims)
	if err := v.Verify(pub, sig, claims); err == nil {
		t.Fatal("future timestamp accepted")
	}
}

func TestInvalidSignature(t *testing.T) {
	pub, _, _ := ed25519.GenerateKey(rand.Reader)
	v := auth.NewVerifier()

	body := []byte(`{}`)
	sum := sha256.Sum256(body)
	claims := auth.RequestClaims{
		Method:  "GET",
		Path:    "/v1/health",
		Ts:      time.Now(),
		BodySHA: sum,
	}
	// Sign with a different key.
	_, otherPriv, _ := ed25519.GenerateKey(rand.Reader)
	badSig := auth.Sign(otherPriv, claims)
	if err := v.Verify(pub, badSig, claims); err == nil {
		t.Fatal("invalid signature accepted")
	}
}
