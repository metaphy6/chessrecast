package admin

import (
	"sync"
	"time"
)

// AutoKillSwitch wraps a KillSwitch and trips it automatically if no
// acknowledgement arrives within T_ack.
//
// Intended for solo-operator deployments (bus factor = 1): if the on-call
// cannot acknowledge a P2P_HEALTH_CRITICAL alert within the configured window,
// the system fails closed rather than remaining open unattended.
//
// Usage:
//
//	aks := admin.NewAutoKillSwitch(ks, 60*time.Minute, func() {
//	    // notify, open incident, etc.
//	})
//	aks.Arm()       // start the T_ack timer
//	aks.Acknowledge() // call when on-call has acknowledged; cancels the timer
//	aks.Reset()    // re-arm for the next alert cycle
//	aks.Stop()      // shut down the background goroutine
type AutoKillSwitch struct {
	ks      *KillSwitch
	tAck    time.Duration
	onFire  func()
	mu      sync.Mutex
	timer   *time.Timer
	stopped bool
}

// NewAutoKillSwitch creates an AutoKillSwitch that will call ks.Disable() and
// invoke onFire (if non-nil) if Acknowledge is not called within tAck after Arm.
func NewAutoKillSwitch(ks *KillSwitch, tAck time.Duration, onFire func()) *AutoKillSwitch {
	return &AutoKillSwitch{
		ks:     ks,
		tAck:   tAck,
		onFire: onFire,
	}
}

// Arm starts the T_ack countdown. If Acknowledge is not called within tAck,
// the KillSwitch is disabled and onFire is invoked.
// Arm is idempotent: calling it while already armed resets the timer.
func (a *AutoKillSwitch) Arm() {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.stopped {
		return
	}

	// Cancel any existing timer.
	if a.timer != nil {
		a.timer.Stop()
	}

	a.timer = time.AfterFunc(a.tAck, func() {
		a.ks.Disable()
		if a.onFire != nil {
			a.onFire()
		}
	})
}

// Acknowledge cancels the pending T_ack timer. The KillSwitch is not
// modified. Call this when the on-call has acknowledged the alert.
func (a *AutoKillSwitch) Acknowledge() {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.timer != nil {
		a.timer.Stop()
		a.timer = nil
	}
}

// Reset re-arms the AutoKillSwitch after it has fired (or after Acknowledge).
// Equivalent to calling Acknowledge then Arm.
func (a *AutoKillSwitch) Reset() {
	a.Arm()
}

// Stop permanently disarms the AutoKillSwitch and prevents further firings.
// After Stop, Arm and Reset are no-ops.
func (a *AutoKillSwitch) Stop() {
	a.mu.Lock()
	defer a.mu.Unlock()

	if a.timer != nil {
		a.timer.Stop()
		a.timer = nil
	}
	a.stopped = true
}
