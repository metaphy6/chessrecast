// Package attest provides device/connection integrity checks including GeoIP and ASN risk scoring.
package attest

import (
	"fmt"
	"net"
)

// RiskLevel represents an assessed connection risk.
type RiskLevel int

const (
	RiskLow    RiskLevel = iota
	RiskMedium           // elevated risk — challenge with PoW
	RiskHigh             // hostile region — reject
)

// IPMeta contains resolved metadata for an IP address.
type IPMeta struct {
	IP          net.IP
	CountryCode string
	ASN         uint32
}

// Assessor evaluates IP addresses against GeoIP/ASN risk tables.
type Assessor struct {
	hostileCountries map[string]bool
	hostileASNs      map[uint32]bool
	mediumASNs       map[uint32]bool
}

// NewAssessor returns an Assessor with the given hostile/medium classification tables.
func NewAssessor(hostileCountries []string, hostileASNs []uint32, mediumASNs []uint32) *Assessor {
	hc := make(map[string]bool, len(hostileCountries))
	for _, c := range hostileCountries {
		hc[c] = true
	}
	ha := make(map[uint32]bool, len(hostileASNs))
	for _, a := range hostileASNs {
		ha[a] = true
	}
	ma := make(map[uint32]bool, len(mediumASNs))
	for _, a := range mediumASNs {
		ma[a] = true
	}
	return &Assessor{hostileCountries: hc, hostileASNs: ha, mediumASNs: ma}
}

// Assess evaluates the risk level for a given IP/country/ASN triple.
func (a *Assessor) Assess(meta IPMeta) (RiskLevel, error) {
	if meta.IP == nil {
		return RiskHigh, fmt.Errorf("missing IP address")
	}
	// Private / loopback → low risk (dev/test environments).
	if meta.IP.IsLoopback() || meta.IP.IsPrivate() {
		return RiskLow, nil
	}
	if a.hostileCountries[meta.CountryCode] || a.hostileASNs[meta.ASN] {
		return RiskHigh, nil
	}
	if a.mediumASNs[meta.ASN] {
		return RiskMedium, nil
	}
	return RiskLow, nil
}
