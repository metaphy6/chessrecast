package invites

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"sync"
	"time"
)

// §6.7.2 Single-use invite-token service.
//
// Token layout (raw bytes, before base64url encoding):
//
//	[pubkey 32 B][nonce 16 B][expiry_u32_be 4 B][hmac_sha256 32 B] = 84 bytes
//
// The HMAC is over pubkey || nonce || expiry.

const (
	pubkeyLen  = 32
	nonceLen   = 16
	expiryLen  = 4
	hmacLen    = 32
	tokenLen   = pubkeyLen + nonceLen + expiryLen + hmacLen // 84
	DefaultTTL = 24 * time.Hour
)

// Sentinel errors.
var (
	ErrInviteLinkExpired  = errors.New("INVITE_LINK_EXPIRED")
	ErrInviteLinkReplayed = errors.New("INVITE_LINK_REPLAYED")
	ErrInviteLinkInvalid  = errors.New("INVITE_LINK_INVALID")
)

// Service generates and redeems single-use invite tokens.
type Service struct {
	mu       sync.Mutex
	secret   []byte
	redeemed map[string]struct{} // set of base64url nonces already used
	now      func() time.Time    // injectable for testing
}

// New returns a Service authenticated with the given HMAC secret.
// The secret should be at least 32 bytes of high-entropy random data.
func New(hmacSecret []byte) *Service {
	return &Service{
		secret:   hmacSecret,
		redeemed: make(map[string]struct{}),
		now:      time.Now,
	}
}

// Generate creates a new invite token for [pubkey].  The token expires after
// [ttl] from now.  [pubkey] must be exactly 32 bytes.
func (s *Service) Generate(pubkey []byte, ttl time.Duration) (string, error) {
	if len(pubkey) != pubkeyLen {
		return "", errors.New("pubkey must be 32 bytes")
	}

	nonce := make([]byte, nonceLen)
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}

	expiry := uint32(s.now().Add(ttl).Unix())
	expiryBytes := make([]byte, expiryLen)
	binary.BigEndian.PutUint32(expiryBytes, expiry)

	mac := s.computeMAC(pubkey, nonce, expiryBytes)

	raw := make([]byte, 0, tokenLen)
	raw = append(raw, pubkey...)
	raw = append(raw, nonce...)
	raw = append(raw, expiryBytes...)
	raw = append(raw, mac...)

	return base64.RawURLEncoding.EncodeToString(raw), nil
}

// Redeem validates and redeems [token].  Returns the embedded pubkey on
// success.  Returns ErrInviteLinkExpired, ErrInviteLinkReplayed, or
// ErrInviteLinkInvalid on failure.  A token can only be redeemed once.
func (s *Service) Redeem(token string) (pubkey []byte, err error) {
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil || len(raw) != tokenLen {
		return nil, ErrInviteLinkInvalid
	}

	pubkey = raw[:pubkeyLen]
	nonce := raw[pubkeyLen : pubkeyLen+nonceLen]
	expiryBytes := raw[pubkeyLen+nonceLen : pubkeyLen+nonceLen+expiryLen]
	gotMAC := raw[pubkeyLen+nonceLen+expiryLen:]

	expectedMAC := s.computeMAC(pubkey, nonce, expiryBytes)
	if !hmac.Equal(gotMAC, expectedMAC) {
		return nil, ErrInviteLinkInvalid
	}

	expiry := time.Unix(int64(binary.BigEndian.Uint32(expiryBytes)), 0)
	if s.now().After(expiry) {
		return nil, ErrInviteLinkExpired
	}

	nonceKey := base64.RawURLEncoding.EncodeToString(nonce)
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, seen := s.redeemed[nonceKey]; seen {
		return nil, ErrInviteLinkReplayed
	}
	s.redeemed[nonceKey] = struct{}{}

	return pubkey, nil
}

func (s *Service) computeMAC(pubkey, nonce, expiryBytes []byte) []byte {
	h := hmac.New(sha256.New, s.secret)
	h.Write(pubkey)
	h.Write(nonce)
	h.Write(expiryBytes)
	return h.Sum(nil)
}
