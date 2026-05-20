// Phase 17 §17.4.2 — 4-hour soak leak detection ≤ 1 MB net RSS drift.
//
// The actual 4-hour soak runs nightly on a real device in CI.
// This unit test verifies the budget constant is registered correctly.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Memory leak soak budget (§17.4.2)', () {
    late Map<String, dynamic> leaf;

    setUpAll(() {
      final budgetFile = File('../agent/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'agent/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      leaf = (tree['leaves'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (l) => l['id'] == 'stability.leak_drift_4h_soak_mb',
            orElse: () =>
                fail('leaf stability.leak_drift_4h_soak_mb not found'),
          );
    });

    test('4-hour soak cap ≤ 1 MB drift', () {
      expect(leaf['cap'], equals(1));
      expect(leaf['units'], equals('mb'));
    });

    test('cap_type is max', () {
      expect(leaf['cap_type'], equals('max'));
    });

    test('owning section is §17.4.2', () {
      expect(leaf['owning_section'], equals('§17.4.2'));
    });

    test('baseline within cap', () {
      expect(
        (leaf['baseline'] as num).toDouble(),
        lessThanOrEqualTo(1.0),
        reason: 'leak soak baseline exceeds 1 MB cap',
      );
    });
  });
}
