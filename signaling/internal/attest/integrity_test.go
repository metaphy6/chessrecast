package attest_test

import (
	"net"
	"testing"

	"github.com/chessrecast/signaling/internal/attest"
)

func newTestAssessor() *attest.Assessor {
	return attest.NewAssessor(
		[]string{"XX"},        // hostile country
		[]uint32{64496},       // hostile ASN
		[]uint32{64511},       // medium ASN
	)
}

// TestIntegrityLowRisk verifies clean IPs are passed through.
func TestIntegrityLowRisk(t *testing.T) {
	a := newTestAssessor()
	risk, err := a.Assess(attest.IPMeta{IP: net.ParseIP("203.0.113.5"), CountryCode: "US", ASN: 12345})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if risk != attest.RiskLow {
		t.Fatalf("expected RiskLow, got %v", risk)
	}
}

// TestIntegrityHostileCountry verifies IPs from hostile countries are high risk.
func TestIntegrityHostileCountry(t *testing.T) {
	a := newTestAssessor()
	risk, err := a.Assess(attest.IPMeta{IP: net.ParseIP("203.0.113.6"), CountryCode: "XX", ASN: 99999})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if risk != attest.RiskHigh {
		t.Fatalf("expected RiskHigh for hostile country, got %v", risk)
	}
}

// TestIntegrityHostileASN verifies IPs from hostile ASNs are high risk.
func TestIntegrityHostileASN(t *testing.T) {
	a := newTestAssessor()
	risk, err := a.Assess(attest.IPMeta{IP: net.ParseIP("203.0.113.7"), CountryCode: "DE", ASN: 64496})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if risk != attest.RiskHigh {
		t.Fatalf("expected RiskHigh for hostile ASN, got %v", risk)
	}
}

// TestIntegrityMediumASN verifies IPs from medium-risk ASNs get challenged.
func TestIntegrityMediumASN(t *testing.T) {
	a := newTestAssessor()
	risk, err := a.Assess(attest.IPMeta{IP: net.ParseIP("198.51.100.1"), CountryCode: "NL", ASN: 64511})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if risk != attest.RiskMedium {
		t.Fatalf("expected RiskMedium for medium ASN, got %v", risk)
	}
}

// TestIntegrityLoopback verifies loopback addresses are always low risk.
func TestIntegrityLoopback(t *testing.T) {
	a := newTestAssessor()
	risk, err := a.Assess(attest.IPMeta{IP: net.ParseIP("127.0.0.1"), CountryCode: "XX", ASN: 64496})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if risk != attest.RiskLow {
		t.Fatalf("loopback should always be RiskLow, got %v", risk)
	}
}

// TestIntegrityMissingIP verifies nil IP returns an error.
func TestIntegrityMissingIP(t *testing.T) {
	a := newTestAssessor()
	_, err := a.Assess(attest.IPMeta{IP: nil})
	if err == nil {
		t.Fatal("expected error for nil IP")
	}
}
