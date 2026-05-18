// Package federation provides peer-discovery and cross-server play stubs (§7 bullet-5).
package federation

import (
	"errors"
	"fmt"
	"net/url"
)

// ErrCapabilityMismatch is returned when two servers cannot negotiate capabilities.
var ErrCapabilityMismatch = errors.New("federation: capability mismatch")

// ServerCapabilities describes what a signaling server supports.
type ServerCapabilities struct {
	WireVersion   uint8
	EngineVersion uint8
	SupportedMods []string
}

// FederationPeer represents a remote signaling server.
type FederationPeer struct {
	WellKnownURL url.URL
	Capabilities *ServerCapabilities
}

// Registry holds discovered federation peers.
type Registry struct {
	peers []*FederationPeer
}

// Register adds a peer after capability negotiation.
// Returns ErrCapabilityMismatch if [local] and [remote] cannot agree.
func (r *Registry) Register(local, remote *ServerCapabilities, peerURL url.URL) (*FederationPeer, error) {
	if local.WireVersion != remote.WireVersion {
		return nil, fmt.Errorf("%w: wire_version local=%d remote=%d",
			ErrCapabilityMismatch, local.WireVersion, remote.WireVersion)
	}
	peer := &FederationPeer{
		WellKnownURL: peerURL,
		Capabilities: remote,
	}
	r.peers = append(r.peers, peer)
	return peer, nil
}

// Peers returns all registered federation peers.
func (r *Registry) Peers() []*FederationPeer {
	return append([]*FederationPeer(nil), r.peers...)
}

// PeerCount returns the number of registered peers.
func (r *Registry) PeerCount() int {
	return len(r.peers)
}
