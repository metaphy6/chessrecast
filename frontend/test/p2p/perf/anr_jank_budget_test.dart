// Phase 17 §17.4.3 — ANR / frame-jank ≤ 0.05 % of frames.
//
// Synthetic CI proxy: verifies the cap is registered correctly in the
// budget tree. Real measurement runs in the device-matrix CI job.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ANR / frame-jank budget (§17.4.3)', () {
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
            (l) => l['id'] == 'stability.anr_pct_of_frames',
            orElse: () => fail('leaf stability.anr_pct_of_frames not found'),
          );
    });

    test('ANR cap ≤ 0.05 % of frames', () {
      expect(leaf['cap'], equals(0.05));
      expect(leaf['units'], equals('pct'));
    });

    test('cap_type is max', () {
      expect(leaf['cap_type'], equals('max'));
    });

    test('owning section is §17.4.3', () {
      expect(leaf['owning_section'], equals('§17.4.3'));
    });

    test('baseline within cap', () {
      expect(
        (leaf['baseline'] as num).toDouble(),
        lessThanOrEqualTo(0.05),
        reason: 'ANR baseline exceeds 0.05 % cap',
      );
    });
  });
}
