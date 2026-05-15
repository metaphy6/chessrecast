// Package offers handles SDP offer/answer exchange between peers.
package offers

import (
	"errors"
	"strings"
)

// MaxPendingOffersPerAccount is the per-account pending-offer cap (§3.9).
const MaxPendingOffersPerAccount = 16

// MaxSDPBytes is the maximum SDP payload size in bytes (§3.9).
const MaxSDPBytes = 16 * 1024 // 16 KB

// ErrSDPTooLarge is returned when the SDP exceeds MaxSDPBytes.
var ErrSDPTooLarge = errors.New("SDP_TOO_LARGE: payload exceeds 16 KB limit")

// ErrSDPInvalidMedia is returned when the SDP contains non-data media lines.
var ErrSDPInvalidMedia = errors.New("SDP_INVALID_MEDIA: only application/datachannel m= lines are permitted")

// ValidateSDP checks the SDP payload for size and content policy.
func ValidateSDP(sdp string) error {
	if len(sdp) > MaxSDPBytes {
		return ErrSDPTooLarge
	}
	// Reject any m= line that is not application (data channel).
	for _, line := range strings.Split(sdp, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "m=") && !strings.HasPrefix(line, "m=application") {
			return ErrSDPInvalidMedia
		}
	}
	return nil
}

