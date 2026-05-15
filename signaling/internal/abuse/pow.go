// Package abuse provides proof-of-work (scrypt-based) challenge/response
// for rate-limiting register/rebind under burst conditions.
package abuse

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"

	"golang.org/x/crypto/scrypt"
)

// Params holds scrypt parameters for the PoW puzzle.
type Params struct {
	N       int    // CPU/memory cost
	R       int    // block size
	P       int    // parallelism
	KeyLen  int    // output bytes
	Prefix  string // required hex prefix
}

// DefaultParams returns production-safe (but fast for tests) parameters.
func DefaultParams() Params {
	return Params{N: 1024, R: 1, P: 1, KeyLen: 32, Prefix: "00"}
}

// Challenge contains a random nonce the client must solve.
type Challenge struct {
	Nonce  string // hex-encoded random bytes
	Params Params
}

// NewChallenge generates a random challenge.
func NewChallenge(p Params) (Challenge, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return Challenge{}, fmt.Errorf("rand: %w", err)
	}
	return Challenge{Nonce: hex.EncodeToString(b), Params: p}, nil
}

// Solve brute-forces a solution to the challenge: returns a counter whose
// scrypt(nonce+counter) has the required hex prefix.
func Solve(c Challenge) (string, error) {
	nonce, err := hex.DecodeString(c.Nonce)
	if err != nil {
		return "", fmt.Errorf("decode nonce: %w", err)
	}
	prefix, err := hex.DecodeString(c.Params.Prefix)
	if err != nil {
		return "", fmt.Errorf("decode prefix: %w", err)
	}
	for i := 0; i < 1<<20; i++ {
		candidate := fmt.Sprintf("%08x", i)
		input := append(nonce, []byte(candidate)...)
		hash, err := scrypt.Key(input, nonce, c.Params.N, c.Params.R, c.Params.P, c.Params.KeyLen)
		if err != nil {
			return "", fmt.Errorf("scrypt: %w", err)
		}
		if subtle.ConstantTimeCompare(hash[:len(prefix)], prefix) == 1 {
			return candidate, nil
		}
	}
	return "", errors.New("no solution found within search space")
}

// Verify checks that the given solution satisfies the challenge.
func Verify(c Challenge, solution string) error {
	nonce, err := hex.DecodeString(c.Nonce)
	if err != nil {
		return fmt.Errorf("decode nonce: %w", err)
	}
	prefix, err := hex.DecodeString(c.Params.Prefix)
	if err != nil {
		return fmt.Errorf("decode prefix: %w", err)
	}
	input := append(nonce, []byte(solution)...)
	hash, err := scrypt.Key(input, nonce, c.Params.N, c.Params.R, c.Params.P, c.Params.KeyLen)
	if err != nil {
		return fmt.Errorf("scrypt: %w", err)
	}
	if subtle.ConstantTimeCompare(hash[:len(prefix)], prefix) != 1 {
		return errors.New("invalid proof-of-work solution")
	}
	return nil
}
