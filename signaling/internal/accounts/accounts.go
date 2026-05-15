// Package accounts manages device identities and registration.
package accounts

import (
	"errors"
	"sync"
	"time"
)

// MaxDevicesPerAccount is the per-account active-device cap (§3.9).
const MaxDevicesPerAccount = 8

// ErrDeviceCapExceeded is returned when a new device registration would exceed MaxDevicesPerAccount.
var ErrDeviceCapExceeded = errors.New("DEVICE_CAP_EXCEEDED: per-account device limit reached")

// Device is an entry in the account's device registry.
type Device struct {
	DevicePub  string
	LastSeen   time.Time
}

// Registry is an in-memory device registry per account.
type Registry struct {
	mu      sync.Mutex
	devices map[string][]Device // accountPub → []Device
}

// NewRegistry returns an empty Registry.
func NewRegistry() *Registry {
	return &Registry{devices: make(map[string][]Device)}
}

// Register adds a device to an account. If the account already has MaxDevicesPerAccount
// devices, the oldest-by-last-seen device is evicted first.
// Returns ErrDeviceCapExceeded if eviction cannot create room (currently never, but
// exported for callers that want to distinguish cap-hit from other errors).
func (r *Registry) Register(accountPub, devicePub string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	devs := r.devices[accountPub]

	// Dedup: if the device is already registered, update last_seen.
	for i, d := range devs {
		if d.DevicePub == devicePub {
			devs[i].LastSeen = time.Now()
			r.devices[accountPub] = devs
			return nil
		}
	}

	// Evict oldest device if at cap.
	if len(devs) >= MaxDevicesPerAccount {
		oldest := 0
		for i, d := range devs {
			if d.LastSeen.Before(devs[oldest].LastSeen) {
				oldest = i
			}
		}
		devs = append(devs[:oldest], devs[oldest+1:]...)
	}

	devs = append(devs, Device{DevicePub: devicePub, LastSeen: time.Now()})
	r.devices[accountPub] = devs
	return nil
}

// DeviceCount returns the number of registered devices for an account.
func (r *Registry) DeviceCount(accountPub string) int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.devices[accountPub])
}

