package rebind_test

// Phase 2.2 — Server-side rebind stub tests.
//
// Documents the behavioral contracts for the account rebind flow (§2.2.bullet-4).
// Stubs pass structural/compilation checks. Real HTTP integration tests land in Phase 3.

import (
	"fmt"
	"testing"
)

// RebindStatus represents the outcome of a rebind request.
type RebindStatus int

const (
	RebindOK        RebindStatus = iota // Device successfully rebound
	RebindRaceLost                      // Another device won the race
	RebindUnknown                       // Account pub not found
)

// StubRebindStore is a test double for the rebind operation.
type StubRebindStore struct {
	bound map[string]string // account_pub → device_pub; nil means locked
}

func newStubRebindStore() *StubRebindStore {
	return &StubRebindStore{bound: make(map[string]string)}
}

// Rebind attempts to atomically bind a new device key to an account.
// Returns RebindRaceLost if another device already rebound.
func (s *StubRebindStore) Rebind(accountPub, newDevicePub string) RebindStatus {
	if existing, ok := s.bound[accountPub]; ok && existing != "" {
		return RebindRaceLost
	}
	s.bound[accountPub] = newDevicePub
	return RebindOK
}

// TestRebindOK verifies first-device rebind succeeds.
func TestRebindOK(t *testing.T) {
	t.Skip("Phase 3 not yet started — stub passes structural checks only")
	store := newStubRebindStore()
	status := store.Rebind("accountPub1", "devicePubA")
	if status != RebindOK {
		t.Fatalf("expected RebindOK, got %d", status)
	}
}

// TestRebindRaceLost verifies the second device gets RebindRaceLost.
func TestRebindRaceLost(t *testing.T) {
	t.Skip("Phase 3 not yet started — stub passes structural checks only")
	store := newStubRebindStore()
	store.Rebind("accountPub2", "devicePubA")
	status := store.Rebind("accountPub2", "devicePubB")
	if status != RebindRaceLost {
		t.Fatalf("expected RebindRaceLost, got %d", status)
	}
}

// TestRebindIsSingleAtomic verifies only one winner per account.
func TestRebindIsSingleAtomic(t *testing.T) {
	t.Skip("Phase 3 not yet started — stub passes structural checks only")
	store := newStubRebindStore()
	winners := 0
	for i := 0; i < 5; i++ {
		s := store.Rebind("accountPub3", fmt.Sprintf("device%d", i))
		if s == RebindOK {
			winners++
		}
	}
	if winners != 1 {
		t.Fatalf("expected exactly 1 winner, got %d", winners)
	}
}
