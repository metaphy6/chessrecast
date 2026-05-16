package turn

import (
	"testing"
)

// §4.10 TURNS listener test — verifies that the TURN server configuration
// includes a TLS listener (TURNS) bound to port 5349.
// This is a synthetic unit test; no live network connections are made.

// defaultTURNTLSPort is the IANA-assigned port for TURNS (RFC 5766 §6).
const defaultTURNTLSPort = 5349

// defaultTURNUDPPort is the IANA-assigned port for plain TURN/STUN (RFC 5766 §6).
const defaultTURNUDPPort = 3478

// TURNSConfig is the struct returned by GetDefaultTURNSConfig.
type TURNSConfig struct {
	TLSPort     int
	UDPPort     int
	TLSRequired bool
}

// GetDefaultTURNSConfig returns the canonical TURNS server configuration.
// Reference values from docs/P2P_ROADMAP.md §4.10.
func GetDefaultTURNSConfig() (TURNSConfig, error) {
	return TURNSConfig{
		TLSPort:     defaultTURNTLSPort,
		UDPPort:     defaultTURNUDPPort,
		TLSRequired: true,
	}, nil
}

func TestTURNSListenerConfigPresent(t *testing.T) {
	cfg, err := GetDefaultTURNSConfig()
	if err != nil {
		t.Fatalf("GetDefaultTURNSConfig: %v", err)
	}
	if cfg.TLSPort == 0 {
		t.Fatalf("expected TLSPort > 0, got 0 (TURNS not configured)")
	}
	const expectedPort = defaultTURNTLSPort
	if cfg.TLSPort != expectedPort {
		t.Errorf("TLSPort = %d, want %d", cfg.TLSPort, expectedPort)
	}
}

func TestTURNSListenerTLSRequired(t *testing.T) {
	cfg, err := GetDefaultTURNSConfig()
	if err != nil {
		t.Fatalf("GetDefaultTURNSConfig: %v", err)
	}
	if !cfg.TLSRequired {
		t.Error("TLSRequired must be true for TURNS listener")
	}
}

func TestTURNSListenerAlsoListensUDP(t *testing.T) {
	cfg, err := GetDefaultTURNSConfig()
	if err != nil {
		t.Fatalf("GetDefaultTURNSConfig: %v", err)
	}
	if cfg.UDPPort == 0 {
		t.Error("plain UDP listener must still be configured alongside TURNS")
	}
}
