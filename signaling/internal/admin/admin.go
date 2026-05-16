// Package admin provides server-side admin controls for the P2P signaling
// server, including the kill-switch that causes /v1/offers to return 503.
package admin

import (
	"errors"
	"net/http"
	"sync/atomic"
	"time"
)

// ErrP2PDisabled is returned when the P2P feature is administratively disabled.
var ErrP2PDisabled = errors.New("P2P_DISABLED: service temporarily unavailable")

// RetryAfterSeconds is the value written to the Retry-After header when
// responding with 503 due to admin disable.
const RetryAfterSeconds = 600 // 10 minutes

// KillSwitch holds the global admin-disable flag for the P2P feature.
// Use NewKillSwitch() to create an instance; the zero value is enabled (not
// disabled), matching production-safe defaults.
type KillSwitch struct {
	disabled atomic.Bool
}

// NewKillSwitch returns a KillSwitch in the enabled (not-disabled) state.
func NewKillSwitch() *KillSwitch {
	return &KillSwitch{}
}

// Disable turns off the P2P feature globally.
// After this call, GuardHTTP returns 503 and IsDisabled returns true.
func (k *KillSwitch) Disable() {
	k.disabled.Store(true)
}

// Enable re-enables the P2P feature.
func (k *KillSwitch) Enable() {
	k.disabled.Store(false)
}

// IsDisabled reports whether the kill-switch is currently engaged.
func (k *KillSwitch) IsDisabled() bool {
	return k.disabled.Load()
}

// GuardHTTP is an http.Handler middleware that returns 503 with Retry-After
// and a JSON error body when the P2P feature is admin-disabled.
// When enabled it calls next.
func (k *KillSwitch) GuardHTTP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if k.disabled.Load() {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Retry-After", itoa(RetryAfterSeconds))
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"error":"P2P_DISABLED","retryAfterSeconds":` +
				itoa(RetryAfterSeconds) + `}`))
			return
		}
		next.ServeHTTP(w, r)
	})
}

// Guard returns ErrP2PDisabled when the kill-switch is engaged, or nil when
// the feature is enabled.  Use this for non-HTTP code paths.
func (k *KillSwitch) Guard() error {
	if k.disabled.Load() {
		return ErrP2PDisabled
	}
	return nil
}

// RetryAfter returns the recommended back-off as a time.Duration.
func RetryAfter() time.Duration {
	return time.Duration(RetryAfterSeconds) * time.Second
}

// itoa is a minimal int-to-string helper to avoid importing strconv.
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	buf := make([]byte, 0, 10)
	for n > 0 {
		buf = append([]byte{byte('0' + n%10)}, buf...)
		n /= 10
	}
	return string(buf)
}
