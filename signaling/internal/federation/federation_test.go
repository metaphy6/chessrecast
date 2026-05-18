// federation_test.go — §7 bullet-5 proof test
package federation_test

import (
	"net/url"
	"testing"

	"github.com/chessrecast/signaling/internal/federation"
)

// TestFederationRegisterSuccess verifies a peer with matching wire_version is registered.
func TestFederationRegisterSuccess(t *testing.T) {
	reg := &federation.Registry{}
	local := &federation.ServerCapabilities{
		WireVersion:   1,
		EngineVersion: 1,
		SupportedMods: []string{"heir", "friendly_fire"},
	}
	remote := &federation.ServerCapabilities{
		WireVersion:   1,
		EngineVersion: 1,
		SupportedMods: []string{"heir"},
	}
	u, _ := url.Parse("wss://peer.example.com")
	peer, err := reg.Register(local, remote, *u)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if peer == nil {
		t.Fatal("expected non-nil peer")
	}
	if reg.PeerCount() != 1 {
		t.Fatalf("peer count = %d, want 1", reg.PeerCount())
	}
}

// TestFederationCapabilityMismatch verifies that version mismatch returns an error.
func TestFederationCapabilityMismatch(t *testing.T) {
	reg := &federation.Registry{}
	local := &federation.ServerCapabilities{WireVersion: 1}
	remote := &federation.ServerCapabilities{WireVersion: 2}
	u, _ := url.Parse("wss://peer.example.com")
	_, err := reg.Register(local, remote, *u)
	if err == nil {
		t.Fatal("expected capability mismatch error")
	}
}

// TestFederationPeersListed verifies all registered peers are returned.
func TestFederationPeersListed(t *testing.T) {
	reg := &federation.Registry{}
	cap := &federation.ServerCapabilities{WireVersion: 1}
	for i := 0; i < 3; i++ {
		u, _ := url.Parse("wss://peer.example.com")
		reg.Register(cap, cap, *u) //nolint:errcheck
	}
	if len(reg.Peers()) != 3 {
		t.Fatalf("peers=%d want 3", len(reg.Peers()))
	}
}
