// Package config manages signed configuration delivery and signing key rotation (§3.11).
package config

import (
	"crypto/ed25519"
	"errors"
	"sync"
	"time"
)

// ErrNoTrustKey is returned when no trusted key can verify the config signature.
var ErrNoTrustKey = errors.New("config signature not verified by any trusted key")

// KeySet holds the currently active signing key plus the previous key (kept
// during the one-app-update-cycle overlap window after rotation).
type KeySet struct {
	mu           sync.RWMutex
	current      ed25519.PublicKey
	previous     ed25519.PublicKey
	rotatedAt    time.Time
}

// NewKeySet initialises a KeySet with the provided current public key.
func NewKeySet(current ed25519.PublicKey) *KeySet {
	return &KeySet{current: current, rotatedAt: time.Now()}
}

// Rotate replaces the current key with newKey, retaining the old key in previous
// for one update cycle.
func (ks *KeySet) Rotate(newKey ed25519.PublicKey) {
	ks.mu.Lock()
	defer ks.mu.Unlock()
	ks.previous = ks.current
	ks.current = newKey
	ks.rotatedAt = time.Now()
}

// Verify checks the signature against both the current and (if set) previous
// trusted public key. Returns nil if either key validates the payload.
func (ks *KeySet) Verify(payload, sig []byte) error {
	ks.mu.RLock()
	defer ks.mu.RUnlock()
	if len(ks.current) > 0 && ed25519.Verify(ks.current, payload, sig) {
		return nil
	}
	if len(ks.previous) > 0 && ed25519.Verify(ks.previous, payload, sig) {
		return nil
	}
	return ErrNoTrustKey
}

// RotatedAt returns the timestamp of the last key rotation.
func (ks *KeySet) RotatedAt() time.Time {
	ks.mu.RLock()
	defer ks.mu.RUnlock()
	return ks.rotatedAt
}
