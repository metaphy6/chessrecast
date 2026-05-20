// §16.1.2 — Per-severity SLA published in security.txt and P2P_OPERATIONS.md.
//
// Proof: SecurityTxt() returns a valid security.txt payload that contains all
// four severity tiers and their patch SLAs so users can read the disclosure
// policy at /.well-known/security.txt.
package cve_test

import (
	"strings"
	"testing"

	"github.com/chessrecast/signaling/internal/cve"
)

// TestSecurityTxtContainsSLALevels verifies that SecurityTxt() includes
// an entry for every CVSS severity tier (§16.1.2 SLA publication).
func TestSecurityTxtContainsSLALevels(t *testing.T) {
	txt := cve.SecurityTxt()
	if txt == "" {
		t.Fatal("SecurityTxt() returned empty string")
	}

	requiredTerms := []string{
		"Critical", "7",
		"High", "30",
		"Medium", "90",
		"Low",
	}
	for _, term := range requiredTerms {
		if !strings.Contains(txt, term) {
			t.Errorf("SecurityTxt() missing required term %q", term)
		}
	}
}

// TestSecurityTxtContactField verifies that the security.txt contains a
// Contact: header as required by RFC 9116 §2.5.3.
func TestSecurityTxtContactField(t *testing.T) {
	txt := cve.SecurityTxt()
	if !strings.Contains(txt, "Contact:") {
		t.Error("SecurityTxt() missing required Contact: field (RFC 9116)")
	}
}

// TestSecurityTxtExpiresField verifies that the security.txt contains an
// Expires: header as required by RFC 9116.
func TestSecurityTxtExpiresField(t *testing.T) {
	txt := cve.SecurityTxt()
	if !strings.Contains(txt, "Expires:") {
		t.Error("SecurityTxt() missing required Expires: field (RFC 9116)")
	}
}
