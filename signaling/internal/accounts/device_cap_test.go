package accounts_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/accounts"
)

// TestDeviceCapEvictsOldest verifies that registering the (MaxDevicesPerAccount+1)th device
// evicts the oldest-by-last-seen device, keeping the count at MaxDevicesPerAccount.
func TestDeviceCapEvictsOldest(t *testing.T) {
	r := accounts.NewRegistry()
	const account = "alice-pub"

	for i := 0; i < accounts.MaxDevicesPerAccount; i++ {
		if err := r.Register(account, "dev-"+string(rune('A'+i))); err != nil {
			t.Fatalf("register device %d: %v", i, err)
		}
	}
	if c := r.DeviceCount(account); c != accounts.MaxDevicesPerAccount {
		t.Fatalf("expected %d devices, got %d", accounts.MaxDevicesPerAccount, c)
	}

	// Register one more — oldest must be evicted.
	if err := r.Register(account, "dev-NEW"); err != nil {
		t.Fatalf("register over cap: %v", err)
	}
	if c := r.DeviceCount(account); c != accounts.MaxDevicesPerAccount {
		t.Fatalf("count should stay at cap after eviction, got %d", c)
	}
}

// TestDeviceCapDedup verifies that re-registering an existing device does not increase the count.
func TestDeviceCapDedup(t *testing.T) {
	r := accounts.NewRegistry()
	r.Register("bob-pub", "dev-1")
	r.Register("bob-pub", "dev-1") // duplicate
	if c := r.DeviceCount("bob-pub"); c != 1 {
		t.Fatalf("duplicate registration must not grow count, got %d", c)
	}
}
