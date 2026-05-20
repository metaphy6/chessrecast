// Package ops — backup-restore drill status (§16.3).
//
// DrillResult captures the outcome of a monthly signaling-DB restore drill.
// GAGateStatus returns DrillStatusFailed when no successful drill has been
// recorded in the past MaxDrillAge (60 days), automatically blocking GA.
package ops

import "time"

// MaxDrillAge is the maximum age of the most recent successful restore drill
// before the GA gate auto-suspends (§16.3.2).
const MaxDrillAge = 60 * 24 * time.Hour

// DrillStatus describes the GA-gate outcome of the restore drill check.
type DrillStatus int

const (
	// DrillStatusOK means a successful drill is on record within MaxDrillAge.
	DrillStatusOK DrillStatus = iota
	// DrillStatusFailed means no successful drill within MaxDrillAge;
	// maps to BACKUP_RESTORE_DRILL_FAILED (§10.3) and suspends the GA gate.
	DrillStatusFailed
)

// DrillResult records the outcome of a single restore drill run.
type DrillResult struct {
	// DrillAt is when the drill was executed.
	DrillAt time.Time
	// P50Ms is the observed P50 restore latency in milliseconds.
	P50Ms int
	// P95Ms is the observed P95 restore latency in milliseconds.
	P95Ms int
	// P50LimitMs is the production P50 plus the 10% tolerance budget.
	P50LimitMs int
	// P95LimitMs is the production P95 plus the 10% tolerance budget.
	P95LimitMs int
	// Success indicates the restored DB passed the integrity check and
	// the Phase 5 L7 chaos smoke suite.
	Success bool
	// DryRun, when true, means the drill ran in simulation mode and did not
	// mutate any production-side state (§16.8.3 dry-run requirement).
	DryRun bool
}

// WithinBounds returns true when both P50 and P95 latencies are within the
// tolerance limits recorded at drill time (≤ 10% of production, §16.3.1).
func (d DrillResult) WithinBounds() bool {
	return d.P50Ms <= d.P50LimitMs && d.P95Ms <= d.P95LimitMs
}

// GAGateStatus evaluates whether the most recent successful restore drill is
// recent enough to keep the GA gate open (§16.3.2).
//
//   - lastSuccessfulDrill: timestamp of the last successful drill
//   - now:                 current time
func GAGateStatus(lastSuccessfulDrill time.Time, now time.Time) DrillStatus {
	if now.Sub(lastSuccessfulDrill) > MaxDrillAge {
		return DrillStatusFailed
	}
	return DrillStatusOK
}
