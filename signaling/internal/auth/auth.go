// Package auth verifies Ed25519 request signatures and prevents replays.
package auth

import (
	"crypto/ed25519"
	"encoding/hex"
	"fmt"
	"sync"
	"time"
)

// MaxAge is the maximum allowed age (or future skew) of a request timestamp.
const MaxAge = 60 * time.Second

// RequestClaims is the authenticated payload signed per request:
// "method:path:unix_ts:body_sha256_hex".
type RequestClaims struct {
	Method  string
	Path    string
	Ts      time.Time
	BodySHA [32]byte
}

func claimBytes(c RequestClaims) []byte {
	return []byte(fmt.Sprintf("%s:%s:%d:%s",
		c.Method, c.Path, c.Ts.Unix(), hex.EncodeToString(c.BodySHA[:])))
}

// Sign creates an Ed25519 signature over the request claims.
func Sign(key ed25519.PrivateKey, c RequestClaims) []byte {
	return ed25519.Sign(key, claimBytes(c))
}

// Verifier verifies request signatures and tracks seen signatures to prevent replay.
type Verifier struct {
	mu   sync.Mutex
	seen map[string]time.Time // sig_hex → first-seen time
}

// NewVerifier returns a new Verifier.
func NewVerifier() *Verifier {
	return &Verifier{seen: make(map[string]time.Time)}
}

// Verify checks that sig is a valid Ed25519 signature over claims by pub,
// that claims.Ts is within ±60 s of now, and that this exact signature has
// not been presented before (replay protection).
func (v *Verifier) Verify(pub ed25519.PublicKey, sig []byte, c RequestClaims) error {
	now := time.Now()
	delta := now.Sub(c.Ts)
	if delta > MaxAge || delta < -MaxAge {
		return fmt.Errorf("timestamp out of ±60 s window: delta=%v", delta)
	}
	if !ed25519.Verify(pub, claimBytes(c), sig) {
		return fmt.Errorf("invalid signature")
	}
	cacheKey := hex.EncodeToString(sig)
	v.mu.Lock()
	defer v.mu.Unlock()
	// Purge expired entries to bound memory growth.
	for k, t := range v.seen {
		if now.Sub(t) > MaxAge*3 {
			delete(v.seen, k)
		}
	}
	if _, exists := v.seen[cacheKey]; exists {
		return fmt.Errorf("replay detected: signature already seen")
	}
	v.seen[cacheKey] = now
	return nil
}
