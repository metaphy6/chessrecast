// Package turn manages TURN credential generation and HMAC key rotation (§3.11).
package turn

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"sync"
	"time"
)

// ErrNoKey is returned when no HMAC key is available.
var ErrNoKey = errors.New("no TURN HMAC key configured")

// Credential is a short-lived TURN username/password pair.
type Credential struct {
	Username string
	Password string
	ExpiresAt time.Time
}

// TTL is the lifetime of a TURN credential.
const TTL = time.Hour

// KeyPair holds a current HMAC key and an optional previous key that remains
// valid during the overlap window after rotation.
type KeyPair struct {
	mu       sync.RWMutex
	current  []byte
	previous []byte
	rotatedAt time.Time
}

// NewKeyPair initialises a KeyPair with the given current key.
func NewKeyPair(currentKey []byte) *KeyPair {
	return &KeyPair{current: currentKey, rotatedAt: time.Now()}
}

// Rotate replaces the current key with newKey, moving the old key to previous.
// The previous key remains valid for TTL (one credential lifetime).
func (kp *KeyPair) Rotate(newKey []byte) {
	kp.mu.Lock()
	defer kp.mu.Unlock()
	kp.previous = kp.current
	kp.current = newKey
	kp.rotatedAt = time.Now()
}

// Mint generates a TURN credential valid for TTL, signed with the current key.
func (kp *KeyPair) Mint(username string) (Credential, error) {
	kp.mu.RLock()
	defer kp.mu.RUnlock()
	if len(kp.current) == 0 {
		return Credential{}, ErrNoKey
	}
	expiry := time.Now().Add(TTL)
	timestamped := fmt.Sprintf("%d:%s", expiry.Unix(), username)
	mac := hmac.New(sha256.New, kp.current)
	mac.Write([]byte(timestamped))
	password := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	return Credential{
		Username:  timestamped,
		Password:  password,
		ExpiresAt: expiry,
	}, nil
}

// Verify checks a credential against both current and previous keys.
// Returns nil if either key validates the credential (overlap window).
func (kp *KeyPair) Verify(username, password string) error {
	kp.mu.RLock()
	defer kp.mu.RUnlock()
	if kp.verifyWithKey(username, password, kp.current) {
		return nil
	}
	if len(kp.previous) > 0 && kp.verifyWithKey(username, password, kp.previous) {
		return nil
	}
	return errors.New("TURN credential verification failed")
}

func (kp *KeyPair) verifyWithKey(username, password string, key []byte) bool {
	mac := hmac.New(sha256.New, key)
	mac.Write([]byte(username))
	expected := base64.StdEncoding.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(password))
}

// RotatedAt returns the timestamp of the last rotation.
func (kp *KeyPair) RotatedAt() time.Time {
	kp.mu.RLock()
	defer kp.mu.RUnlock()
	return kp.rotatedAt
}
