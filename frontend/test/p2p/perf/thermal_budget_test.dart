// Phase 17 §17.3.2 — Thermal cap ≤ 40 °C chassis temperature.
//
// Over 40 °C → spectator/chat shed + one-time toast (§17.3.2).
// Measured via ProcessInfo.thermalState (iOS) / BatteryManager.temperature (Android).
// Synthetic CI proxy: verifies cap is registered correctly in the budget tree.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Thermal budget (§17.3.2)', () {
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
            (l) => l['id'] == 'efficiency.thermal_chassis_max_c',
            orElse: () =>
                fail('leaf efficiency.thermal_chassis_max_c not found'),
          );
    });

    test('cap is 40 °C', () {
      expect(leaf['cap'], equals(40));
      expect(leaf['units'], equals('deg_c'));
    });

    test('cap_type is max', () {
      expect(leaf['cap_type'], equals('max'));
    });

    test('owning section is §17.3.2', () {
      expect(leaf['owning_section'], equals('§17.3.2'));
    });

    test('baseline within cap', () {
      expect(
        (leaf['baseline'] as num).toDouble(),
        lessThanOrEqualTo(40.0),
        reason: 'thermal baseline exceeds 40 °C cap',
      );
    });
  });
}
