// Package abuse: rate-limiter for PoW solution attempts and single-use challenge redeemer (§3.9).
package abuse

import (
	"errors"
	"sync"
	"time"
)

// poWBucket is a simple token-bucket for PoW solution attempts per IP.
type poWBucket struct {
	tokens    float64
	lastRefil time.Time
}

// PoWRateLimiter enforces a per-IP rate limit on PoW solution attempts.
type PoWRateLimiter struct {
	mu          sync.Mutex
	refillPerMin float64
	burst        float64
	buckets      map[string]*poWBucket
}

// NewPoWRateLimiter returns a PoWRateLimiter that allows burst attempts initially
// and refills at refillPerMin tokens per minute.
func NewPoWRateLimiter(refillPerMin, burst float64) *PoWRateLimiter {
	return &PoWRateLimiter{
		refillPerMin: refillPerMin,
		burst:        burst,
		buckets:      make(map[string]*poWBucket),
	}
}

// Allow returns true and consumes one token if the IP has quota available.
func (rl *PoWRateLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	b, ok := rl.buckets[ip]
	if !ok {
		b = &poWBucket{tokens: rl.burst, lastRefil: now}
		rl.buckets[ip] = b
	}

	elapsed := now.Sub(b.lastRefil).Minutes()
	b.tokens += elapsed * rl.refillPerMin
	if b.tokens > rl.burst {
		b.tokens = rl.burst
	}
	b.lastRefil = now

	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// ChallengeRedeemer ensures each challenge nonce is redeemed at most once.
type ChallengeRedeemer struct {
	mu      sync.Mutex
	redeemed map[string]struct{}
}

// NewChallengeRedeemer returns an empty ChallengeRedeemer.
func NewChallengeRedeemer() *ChallengeRedeemer {
	return &ChallengeRedeemer{redeemed: make(map[string]struct{})}
}

// Redeem verifies the solution and records the nonce as used. Returns an error if
// the solution is invalid or the challenge has already been redeemed.
func (cr *ChallengeRedeemer) Redeem(c Challenge, solution string) error {
	cr.mu.Lock()
	defer cr.mu.Unlock()

	if _, used := cr.redeemed[c.Nonce]; used {
		return errors.New("CHALLENGE_ALREADY_REDEEMED: nonce has already been used")
	}
	if err := Verify(c, solution); err != nil {
		return err
	}
	cr.redeemed[c.Nonce] = struct{}{}
	return nil
}
