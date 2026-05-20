// §16.4.1 — SBOM-diff review policy: major crypto dep bumps require a
// kind:shared_edit queue entry and a KAT-vector re-pass.
//
// §16.4.2 — CVE-watcher auto-PR gate: patch-level bumps must pass L1–L7;
// no --force-merge allowed.
//
// Proof: policy constants are present and correctly valued.
package cve_test

import (
	"testing"

	"github.com/chessrecast/signaling/internal/cve"
)

// TestDepPolicyMajorCryptoBumpRequiresReview verifies that the policy constant
// declares major cryptographic dependency bumps require a shared_edit review
// entry and KAT-vector re-pass (§16.4.1).
func TestDepPolicyMajorCryptoBumpRequiresReview(t *testing.T) {
	if !cve.DepPolicyMajorCryptoRequiresSharedEdit {
		t.Error("DepPolicyMajorCryptoRequiresSharedEdit must be true (§16.4.1)")
	}
	if !cve.DepPolicyMajorCryptoRequiresKATRepass {
		t.Error("DepPolicyMajorCryptoRequiresKATRepass must be true (§16.4.1)")
	}
}

// TestDepPolicyForceMergeDisabled verifies that force-merge is declared
// prohibited for CVE-watcher auto-PRs (§16.4.2).
func TestDepPolicyForceMergeDisabled(t *testing.T) {
	if !cve.DepPolicyAutoPRForceMergeDisabled {
		t.Error("DepPolicyAutoPRForceMergeDisabled must be true (§16.4.2)")
	}
}
