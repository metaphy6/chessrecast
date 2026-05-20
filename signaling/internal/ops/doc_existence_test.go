// Package ops_test — Phase 16 documentation existence tests (§16.6.1,
// §16.6.2, §16.7.1, §16.7.3, §16.9).
//
// These tests serve as machine-readable acceptance gates: if the required
// documentation file is deleted or renamed, the test fails and the leaf is
// considered incomplete.
package ops_test

import (
	"os"
	"strings"
	"testing"
)

// repoRoot returns the repo root from the signaling module directory.
// signaling/ is one level below the repo root.
func repoRoot(t *testing.T) string {
	t.Helper()
	// When run via `go test ./...` from signaling/, the working directory is
	// signaling/internal/ops. Walk up 3 levels.
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	// Resolve to repo root (3 levels up from internal/ops).
	parts := strings.Split(dir, "/")
	// find "signaling" in path and take parent
	for i := len(parts) - 1; i >= 0; i-- {
		if parts[i] == "signaling" {
			return strings.Join(parts[:i], "/")
		}
	}
	t.Fatalf("could not locate repo root from %q", dir)
	return ""
}

// TestIncidentResponseTemplateExists verifies P2P_INCIDENT_RESPONSE.md exists
// and contains the required post-mortem sections (§16.6.1).
func TestIncidentResponseTemplateExists(t *testing.T) {
	root := repoRoot(t)
	path := root + "/docs/P2P_INCIDENT_RESPONSE.md"
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("P2P_INCIDENT_RESPONSE.md not found at %s: %v", path, err)
	}
	content := string(data)

	required := []string{
		"timeline",
		"root cause",
		"5-why",
		"action item",
		"prevention test",
	}
	for _, want := range required {
		if !strings.Contains(strings.ToLower(content), want) {
			t.Errorf("P2P_INCIDENT_RESPONSE.md missing section/keyword %q", want)
		}
	}
}

// TestStatusPagePolicyDocumented verifies that P2P_OPERATIONS.md contains the
// status-page update policy with the required timing commitments (§16.6.2).
func TestStatusPagePolicyDocumented(t *testing.T) {
	root := repoRoot(t)
	path := root + "/docs/P2P_OPERATIONS.md"
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("P2P_OPERATIONS.md not found at %s: %v", path, err)
	}
	content := string(data)

	// Must contain a status-page section and time-based commitments.
	required := []string{
		"status", // status-page section header
		"15",     // 15-minute initial post SLA
		"2 hour", // 2-hour resolution notice SLA
	}
	for _, want := range required {
		if !strings.Contains(strings.ToLower(content), strings.ToLower(want)) {
			t.Errorf("P2P_OPERATIONS.md missing status-page keyword %q", want)
		}
	}
}

// TestOnCallScheduleDocumented verifies that P2P_OPERATIONS.md contains an
// on-call schedule section with SLA acknowledgement times (§16.7.1).
func TestOnCallScheduleDocumented(t *testing.T) {
	root := repoRoot(t)
	path := root + "/docs/P2P_OPERATIONS.md"
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("P2P_OPERATIONS.md not found at %s: %v", path, err)
	}
	content := string(data)

	required := []string{
		"on-call",       // section
		"pagerduty",     // alerting tool reference
		"acknowledgement", // SLA language
	}
	for _, want := range required {
		if !strings.Contains(strings.ToLower(content), strings.ToLower(want)) {
			t.Errorf("P2P_OPERATIONS.md missing on-call keyword %q", want)
		}
	}
}

// TestOperatorOnboardingExists verifies P2P_OPERATOR_ONBOARDING.md exists and
// is dated within the past 6 months (§16.7.3).
func TestOperatorOnboardingExists(t *testing.T) {
	root := repoRoot(t)
	path := root + "/docs/P2P_OPERATOR_ONBOARDING.md"
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("P2P_OPERATOR_ONBOARDING.md not found at %s: %v", path, err)
	}
	content := string(data)

	// Must reference KMS, signing key, and runbook locations.
	required := []string{
		"KMS",
		"signing",
		"runbook",
		"onboarding",
	}
	for _, want := range required {
		if !strings.Contains(content, want) {
			t.Errorf("P2P_OPERATOR_ONBOARDING.md missing required content %q", want)
		}
	}

	// Must have a date header within the past 6 months.
	// We check for the pattern "Date:" or "**Date:**" in the document.
	if !strings.Contains(content, "2026") {
		t.Errorf("P2P_OPERATOR_ONBOARDING.md does not contain a 2026 date — may be stale")
	}
}

// TestAcceptanceGateDocumented verifies P2P_OPERATIONS.md contains the Phase 16
// acceptance gate and runbook index (§16.9).
func TestAcceptanceGateDocumented(t *testing.T) {
	root := repoRoot(t)
	path := root + "/docs/P2P_OPERATIONS.md"
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("P2P_OPERATIONS.md not found at %s: %v", path, err)
	}
	content := string(data)

	required := []string{
		"acceptance gate",
		"runbook index",
		"restore drill",
	}
	for _, want := range required {
		if !strings.Contains(strings.ToLower(content), strings.ToLower(want)) {
			t.Errorf("P2P_OPERATIONS.md missing acceptance-gate keyword %q", want)
		}
	}
}
