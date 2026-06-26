// Phase 17 §17.2.1 — Handshake-to-first-move P99 ≤ 5000 ms on LTE.
//
// Synthetic CI proxy: verifies the budget cap and per-leg decomposition are
// registered correctly in bots/baselines/p2p_budgets.json.
// Real measurement is done in the device-matrix CI job.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Handshake-to-first-move P99 budget (§17.2.1)', () {
    late Map<String, dynamic> leaf;

    setUpAll(() {
      final budgetFile = File('../bots/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'bots/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      leaf = (tree['leaves'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (l) => l['id'] == 'perf.handshake_to_first_move_p99_ms',
            orElse: () =>
                fail('leaf perf.handshake_to_first_move_p99_ms not found'),
          );
    });

    test('cap is 5000 ms', () {
      expect(leaf['cap'], equals(5000));
      expect(leaf['units'], equals('ms'));
      expect(leaf['cap_type'], equals('max'));
    });

    test('baseline is within cap', () {
      expect(
        (leaf['baseline'] as num).toDouble(),
        lessThanOrEqualTo(5000.0),
        reason: 'measured baseline exceeds 5000 ms cap',
      );
    });

    test('owning section is §17.2.1', () {
      expect(leaf['owning_section'], equals('§17.2.1'));
    });

    test('per-leg decomposition sums to ≤ cap', () {
      final legDecomp = leaf['leg_decomp'] as Map<String, dynamic>?;
      if (legDecomp != null) {
        final total = legDecomp.values.fold(
          0.0,
          (s, v) => s + (v as num).toDouble(),
        );
        expect(
          total,
          lessThanOrEqualTo(5000.0),
          reason: 'per-leg sum $total ms exceeds total cap 5000 ms',
        );
      }
    });
  });
}
