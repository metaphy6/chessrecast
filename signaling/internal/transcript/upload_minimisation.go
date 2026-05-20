// Package transcript defines what may be uploaded from a completed game.
//
// §9.5 T-M-005 — Data minimisation: only cryptographic proof fields are
// uploaded; no chat content, no move timestamps, no IP addresses.
package transcript

// Transcript is the minimal post-game upload payload.
// Only these fields leave the device.  Adding a new field here requires an
// explicit privacy review and a P2P_PRIVACY.md update.
type Transcript struct {
	// SessionID is the public per-game identifier (not a persistent user ID).
	SessionID string `json:"session_id"`

	// ResultHash is a SHA-256 hash of the final board position + move list,
	// used to verify game integrity without revealing the moves themselves.
	ResultHash []byte `json:"result_hash"`

	// Sig is the Ed25519 signature over ResultHash by the losing side.
	// Proves the loser accepted the result.
	Sig []byte `json:"sig"`

	// CryptoSuiteID identifies the suite used to compute ResultHash + Sig.
	CryptoSuiteID string `json:"crypto_suite_id"`
}

// AllowedFields is the exhaustive set of JSON field names that Transcript may
// contain.  Tests compare reflect-derived field names against this set.
var AllowedFields = map[string]bool{
	"session_id":      true,
	"result_hash":     true,
	"sig":             true,
	"crypto_suite_id": true,
}
