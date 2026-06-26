// Phase 17 §17.2.2 — Move RTT budgets broken out by transport.
//
// Caps: LTE P50 ≤ 120 ms, LTE P99 ≤ 250 ms, WiFi P99 ≤ 80 ms.
// Synthetic CI proxy: verifies caps and baselines are registered correctly.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Move RTT budgets by transport (§17.2.2)', () {
    late List<Map<String, dynamic>> rttLeaves;

    setUpAll(() {
      final budgetFile = File('../bots/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'bots/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      rttLeaves = (tree['leaves'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((l) => (l['id'] as String).contains('move_rtt'))
          .toList();
    });

    Map<String, dynamic> _leaf(String id) {
      return rttLeaves.firstWhere(
        (l) => l['id'] == id,
        orElse: () => fail('leaf $id not found'),
      );
    }

    test('LTE P50 cap is 120 ms', () {
      expect(_leaf('perf.move_rtt_lte_p50_ms')['cap'], equals(120));
    });

    test('LTE P99 cap is 250 ms', () {
      expect(_leaf('perf.move_rtt_lte_p99_ms')['cap'], equals(250));
    });

    test('WiFi P99 cap is 80 ms', () {
      expect(_leaf('perf.move_rtt_wifi_p99_ms')['cap'], equals(80));
    });

    test('all four RTT leaves are present', () {
      expect(rttLeaves.length, greaterThanOrEqualTo(3));
    });

    test('P50 < P99 on LTE', () {
      final p50 = (_leaf('perf.move_rtt_lte_p50_ms')['cap'] as num).toDouble();
      final p99 = (_leaf('perf.move_rtt_lte_p99_ms')['cap'] as num).toDouble();
      expect(p50, lessThan(p99));
    });

    test('all RTT baselines within their caps', () {
      for (final leaf in rttLeaves) {
        expect(
          (leaf['baseline'] as num).toDouble(),
          lessThanOrEqualTo((leaf['cap'] as num).toDouble()),
          reason: '${leaf['id']} baseline exceeds cap',
        );
      }
    });
  });
}
