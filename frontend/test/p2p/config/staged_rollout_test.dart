// §6.4.1 Staged-rollout configuration proof test.
//
// Verifies the StagedRollout config model:
//  - Four-stage 1% → 10% → 50% → 100% ladder is correctly defined.
//  - Minimum soak duration between stages is 24 hours.
//  - Auto-halt threshold is 5% KPI regression.
//  - canEnroll(accountId) correctly buckets into the active cohort.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/config/staged_rollout.dart';

void main() {
  group('StagedRollout §6.4.1', () {
    // ── Stage ladder ───────────────────────────────────────────────────────
    test('defines exactly 4 stages', () {
      expect(StagedRollout.stages, hasLength(4));
    });

    test('stage percentages are 1, 10, 50, 100', () {
      expect(
        StagedRollout.stages.map((s) => s.percentPct).toList(),
        equals([1, 10, 50, 100]),
      );
    });

    test('minimum soak between stages is 24 hours', () {
      for (final stage in StagedRollout.stages) {
        expect(stage.minSoakDuration,
            greaterThanOrEqualTo(const Duration(hours: 24)));
      }
    });

    // ── Auto-halt threshold ────────────────────────────────────────────────
    test('auto-halt threshold is 5 percent', () {
      expect(StagedRollout.autoHaltKpiRegressionPct, equals(5));
    });

    test('isKpiRegressionAboveHaltThreshold returns true at 6% regression', () {
      expect(
        StagedRollout.isKpiRegressionAboveHaltThreshold(6.0),
        isTrue,
      );
    });

    test('isKpiRegressionAboveHaltThreshold returns false at 4% regression', () {
      expect(
        StagedRollout.isKpiRegressionAboveHaltThreshold(4.9),
        isFalse,
      );
    });

    // ── Cohort enrollment ──────────────────────────────────────────────────
    test('canEnroll is true for all accounts when stage is 100%', () {
      final full = RolloutStage(percentPct: 100,
          minSoakDuration: const Duration(hours: 24));
      // Check a spread of account IDs — all must enroll at 100%.
      for (final id in ['a', 'b', 'c', 'z', '0', '9']) {
        expect(full.canEnroll(id), isTrue,
            reason: 'account $id must enroll at 100%');
      }
    });

    test('canEnroll is false for all accounts when stage is 0%', () {
      final none = RolloutStage(percentPct: 0,
          minSoakDuration: const Duration(hours: 24));
      for (final id in ['a', 'b', 'c', 'z', '0', '9']) {
        expect(none.canEnroll(id), isFalse,
            reason: 'account $id must not enroll at 0%');
      }
    });

    test('1% stage enrolls roughly 1 in 100 accounts', () {
      final stage =
          RolloutStage(percentPct: 1, minSoakDuration: const Duration(hours: 24));
      var enrolled = 0;
      for (var i = 0; i < 10000; i++) {
        if (stage.canEnroll('user-$i')) enrolled++;
      }
      // Should be between 0.5% and 2.5% of 10000 for a fair hash distribution.
      expect(enrolled, greaterThan(50));
      expect(enrolled, lessThan(250));
    });

    // ── Alert rules ────────────────────────────────────────────────────────
    test('alertRules returns a non-empty list', () {
      expect(StagedRollout.alertRules, isNotEmpty);
    });

    test('each alert rule has a name and threshold', () {
      for (final rule in StagedRollout.alertRules) {
        expect(rule.name, isNotEmpty);
        expect(rule.haltThreshold, isNotNull);
      }
    });
  });
}
