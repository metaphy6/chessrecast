// §16.3.1 — Monthly backup-restore drill for the signaling DB.
//
// Proof: DrillResult captures whether a restore completed within P50/P95
// bounds and DrillStatus correctly reports BACKUP_RESTORE_DRILL_FAILED when
// results are absent or out-of-bounds.
//
// §16.3.2 — Drill failure → BACKUP_RESTORE_DRILL_FAILED; GA gate auto-suspends
// if no successful drill in the past 60 d.
package ops_test

import (
	"testing"
	"time"

	"github.com/chessrecast/signaling/internal/ops"
)

// TestRestoreDrillSuccessRecorded verifies that a drill result with latencies
// within P50/P95 bounds is recorded as successful (§16.3.1).
func TestRestoreDrillSuccessRecorded(t *testing.T) {
	result := ops.DrillResult{
		DrillAt:    time.Now(),
		P50Ms:      450,
		P95Ms:      900,
		P50LimitMs: 500,
		P95LimitMs: 1000,
		Success:    true,
	}
	if !result.WithinBounds() {
		t.Error("drill within P50/P95 limits must be WithinBounds=true")
	}
}

// TestRestoreDrillP95Breach verifies that a drill exceeding the P95 limit
// is flagged as failed (§16.3.1).
func TestRestoreDrillP95Breach(t *testing.T) {
	result := ops.DrillResult{
		DrillAt:    time.Now(),
		P50Ms:      450,
		P95Ms:      1200, // exceeds 1000 ms limit
		P50LimitMs: 500,
		P95LimitMs: 1000,
		Success:    true,
	}
	if result.WithinBounds() {
		t.Error("drill exceeding P95 limit must be WithinBounds=false")
	}
}

// TestBackupRestoreDrillFailedNoRecent verifies that GAGateStatus returns
// BACKUP_RESTORE_DRILL_FAILED when the most recent successful drill is
// older than 60 days (§16.3.2).
func TestBackupRestoreDrillFailedNoRecent(t *testing.T) {
	now := time.Now()
	// Last successful drill was 61 days ago.
	lastSuccess := now.Add(-61 * 24 * time.Hour)
	status := ops.GAGateStatus(lastSuccess, now)
	if status != ops.DrillStatusFailed {
		t.Errorf("GA gate should be DrillStatusFailed when last drill is >60d ago, got %v", status)
	}
}

// TestBackupRestoreDrillGAGateGreen verifies that a recent successful drill
// keeps the GA gate open (§16.3.2).
func TestBackupRestoreDrillGAGateGreen(t *testing.T) {
	now := time.Now()
	lastSuccess := now.Add(-15 * 24 * time.Hour) // 15 days ago
	status := ops.GAGateStatus(lastSuccess, now)
	if status != ops.DrillStatusOK {
		t.Errorf("GA gate should be DrillStatusOK when last drill is within 60d, got %v", status)
	}
}

// TestBackupRestoreDrillMaxWindow verifies the 60-day window constant
// is exactly 60 days (§16.3.2).
func TestBackupRestoreDrillMaxWindow(t *testing.T) {
	const expected = 60 * 24 * time.Hour
	if ops.MaxDrillAge != expected {
		t.Errorf("MaxDrillAge = %v; want %v", ops.MaxDrillAge, expected)
	}
}
