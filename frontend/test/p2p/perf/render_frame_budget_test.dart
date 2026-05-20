// Phase 17 §17.2.4 — Render frame P99 ≤ 16 ms (60 fps target).
//
// 90 / 120 fps not budgeted in v1 (OQ-49).
// Synthetic CI proxy: verifies cap is correctly registered in the budget tree.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Render frame budget (§17.2.4)', () {
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
            (l) => l['id'] == 'perf.render_frame_p99_ms',
            orElse: () => fail('leaf perf.render_frame_p99_ms not found'),
          );
    });

    test('cap is 16 ms (one 60 fps frame)', () {
      expect(leaf['cap'], equals(16));
      expect(leaf['units'], equals('ms'));
    });

    test('cap_type is max', () {
      expect(leaf['cap_type'], equals('max'));
    });

    test('owning section is §17.2.4', () {
      expect(leaf['owning_section'], equals('§17.2.4'));
    });

    test('baseline within cap', () {
      expect(
        (leaf['baseline'] as num).toDouble(),
        lessThanOrEqualTo(16.0),
        reason: 'render frame baseline exceeds 16 ms cap',
      );
    });
  });
}
