// Package ratelimit provides per-IP and per-account token-bucket rate limiters.
package ratelimit

import (
	"sync"
	"time"
)

// bucket holds the state for a single token-bucket.
type bucket struct {
	tokens   float64
	lastTime time.Time
	mu       sync.Mutex
}

// newBucket creates a bucket starting at cap tokens.
func newBucket(cap float64) *bucket {
	return &bucket{tokens: cap, lastTime: time.Now()}
}

// allow returns true if one token is available (and consumes it), using
// the given refillRate (tokens/second) and cap (maximum tokens).
func (b *bucket) allow(refillRate, cap float64) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	now := time.Now()
	elapsed := now.Sub(b.lastTime).Seconds()
	b.lastTime = now
	b.tokens += elapsed * refillRate
	if b.tokens > cap {
		b.tokens = cap
	}
	if b.tokens < 1 {
		return false
	}
	b.tokens--
	return true
}

// Limiter is a thread-safe map of string key → token bucket.
type Limiter struct {
	mu          sync.RWMutex
	buckets     map[string]*bucket
	refillRate  float64 // tokens per second
	cap         float64 // maximum tokens (burst)
}

// NewLimiter returns a Limiter with the given tokens-per-minute refill rate and burst cap.
func NewLimiter(refillPerMin, burstCap float64) *Limiter {
	return &Limiter{
		buckets:    make(map[string]*bucket),
		refillRate: refillPerMin / 60.0,
		cap:        burstCap,
	}
}

// Allow returns true if the key is within rate limit.
func (l *Limiter) Allow(key string) bool {
	l.mu.RLock()
	b, ok := l.buckets[key]
	l.mu.RUnlock()
	if !ok {
		l.mu.Lock()
		b, ok = l.buckets[key]
		if !ok {
			b = newBucket(l.cap)
			l.buckets[key] = b
		}
		l.mu.Unlock()
	}
	return b.allow(l.refillRate, l.cap)
}
