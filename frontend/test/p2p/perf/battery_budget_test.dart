// Phase 17 §17.3.1 — Battery budget caps.
//
// Pixel 4a / iPhone XR baselines; CI re-measures monthly.
// active blitz ≤ 3.0 % per hour, correspondence idle ≤ 0.4 % per hour.
// Synthetic CI proxy: verifies caps in the budget tree.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Battery budget (§17.3.1)', () {
    late Map<String, Map<String, dynamic>> battLeaves;

    setUpAll(() {
      final budgetFile = File('../bots/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'bots/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      battLeaves = {
        for (final l
            in (tree['leaves'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where((l) => (l['id'] as String).contains('battery')))
          l['id'] as String: l,
      };
    });

    test('two battery leaves present', () {
      expect(battLeaves.length, equals(2));
    });

    test('active blitz cap is 3.0 % / h', () {
      final leaf = battLeaves['efficiency.battery_active_blitz_pct_per_hour']!;
      expect(leaf['cap'], equals(3.0));
      expect(leaf['units'], equals('pct_per_h'));
    });

    test('correspondence idle cap is 0.4 % / h', () {
      final leaf =
          battLeaves['efficiency.battery_correspondence_idle_pct_per_h']!;
      expect(leaf['cap'], equals(0.4));
    });

    test('all battery baselines within caps', () {
      for (final entry in battLeaves.entries) {
        expect(
          (entry.value['baseline'] as num).toDouble(),
          lessThanOrEqualTo((entry.value['cap'] as num).toDouble()),
          reason: '${entry.key} baseline exceeds cap',
        );
      }
    });

    test('active cap > idle cap (blitz draws more power)', () {
      final blitz =
          (battLeaves['efficiency.battery_active_blitz_pct_per_hour']!['cap']
                  as num)
              .toDouble();
      final idle =
          (battLeaves['efficiency.battery_correspondence_idle_pct_per_h']!['cap']
                  as num)
              .toDouble();
      expect(blitz, greaterThan(idle));
    });
  });
}
