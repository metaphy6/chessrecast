// §6.4.1 Staged rollout configuration model.
//
// Models the four-stage 1% → 10% → 50% → 100% GA rollout with 24-hour soaks
// and a 5% KPI-regression auto-halt threshold.
import 'dart:convert';

/// A single rollout alert rule: when the named KPI regresses beyond
/// [haltThreshold] percent, the rollout is automatically halted.
class RolloutAlertRule {
  final String name;
  final double haltThreshold;

  const RolloutAlertRule({required this.name, required this.haltThreshold});
}

/// One stage in the staged-rollout ladder.
class RolloutStage {
  /// Percentage of accounts (0–100) that should be enrolled at this stage.
  final int percentPct;

  /// Minimum time to hold this stage before advancing.
  final Duration minSoakDuration;

  const RolloutStage({
    required this.percentPct,
    required this.minSoakDuration,
  });

  /// Returns `true` when [accountId] should be enrolled at this stage.
  ///
  /// Uses a deterministic hash of [accountId] modulo 100 to select the
  /// cohort. This is stable: the same account is always in or out for a given
  /// [percentPct].
  bool canEnroll(String accountId) {
    if (percentPct <= 0) return false;
    if (percentPct >= 100) return true;
    // Use the last two bytes of a SHA-256-like polynomial hash for
    // deterministic, uniform-ish bucketing without a heavy dependency.
    final bytes = utf8.encode(accountId);
    var h = 0;
    for (final b in bytes) {
      h = ((h * 31) + b) & 0xFFFF;
    }
    return (h % 100) < percentPct;
  }
}

/// Static configuration for the P2P beta → GA staged rollout (§6.4.1).
class StagedRollout {
  StagedRollout._();

  /// The four-step rollout ladder: 1% → 10% → 50% → 100%.
  static const List<RolloutStage> stages = [
    RolloutStage(percentPct: 1, minSoakDuration: Duration(hours: 24)),
    RolloutStage(percentPct: 10, minSoakDuration: Duration(hours: 24)),
    RolloutStage(percentPct: 50, minSoakDuration: Duration(hours: 24)),
    RolloutStage(percentPct: 100, minSoakDuration: Duration(hours: 24)),
  ];

  /// KPI regression percentage above which the rollout is automatically halted.
  static const int autoHaltKpiRegressionPct = 5;

  /// Returns `true` when [regressionPct] exceeds [autoHaltKpiRegressionPct].
  static bool isKpiRegressionAboveHaltThreshold(double regressionPct) {
    return regressionPct > autoHaltKpiRegressionPct;
  }

  /// Dashboard alert rules covering the most critical P2P KPIs.
  static const List<RolloutAlertRule> alertRules = [
    RolloutAlertRule(
      name: 'connection_success_rate_regression',
      haltThreshold: 5.0,
    ),
    RolloutAlertRule(
      name: 'mismatch_rate_above_1e5',
      haltThreshold: 5.0,
    ),
    RolloutAlertRule(
      name: 'backpressure_drop_rate_spike',
      haltThreshold: 5.0,
    ),
    RolloutAlertRule(
      name: 'crash_free_rate_below_threshold',
      haltThreshold: 5.0,
    ),
  ];
}
