// Phase 17 §17.5.1–§17.5.6 — Reliability budget caps.
//
// Covers all six reliability leaves:
//   §17.5.1  MISMATCH rate ≤ 1 / 10⁶ moves
//   §17.5.2  ICE re-establishment success ≥ 99.5 % within 10 s
//   §17.5.3  Push-wake: non-Doze ≥ 95 %, Doze ≥ 80 %
//   §17.5.4  Transcript signature verify ≥ 99.99 %
//   §17.5.5  Recovery unwrap success ≥ 99.5 %
//   §17.5.6  Kill-switch propagation P99 ≤ 10 min
//
// Synthetic CI proxy: verifies caps and cap_type values are registered
// correctly in the budget tree. Real chaos/device measurements run nightly.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reliability budget caps (§17.5.1–§17.5.6)', () {
    late Map<String, Map<String, dynamic>> relLeaves;

    setUpAll(() {
      final budgetFile = File('../bots/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'bots/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      relLeaves = {
        for (final l
            in (tree['leaves'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where((l) => (l['id'] as String).startsWith('reliability.')))
          l['id'] as String: l,
      };
    });

    test('seven reliability leaves are present', () {
      expect(relLeaves.length, equals(7));
    });

    // §17.5.1
    test('MISMATCH rate cap ≤ 1 / million moves', () {
      final leaf = relLeaves['reliability.mismatch_per_million_moves']!;
      expect(leaf['cap'], equals(1));
      expect(leaf['cap_type'], equals('max'));
    });

    // §17.5.2
    test('ICE re-establishment success cap ≥ 99.5 %', () {
      final leaf =
          relLeaves['reliability.ice_reestablish_success_pct_within_10s']!;
      expect(leaf['cap'], equals(99.5));
      expect(leaf['cap_type'], equals('min'));
    });

    // §17.5.3
    test('push-wake non-Doze cap ≥ 95 %', () {
      final leaf = relLeaves['reliability.push_wake_success_pct_non_doze_90s']!;
      expect(leaf['cap'], equals(95));
      expect(leaf['cap_type'], equals('min'));
    });

    test('push-wake Doze cap ≥ 80 %', () {
      final leaf = relLeaves['reliability.push_wake_success_pct_doze_90s']!;
      expect(leaf['cap'], equals(80));
      expect(leaf['cap_type'], equals('min'));
    });

    test('non-Doze wake rate cap > Doze cap', () {
      final nonDoze =
          (relLeaves['reliability.push_wake_success_pct_non_doze_90s']!['cap']
                  as num)
              .toDouble();
      final doze =
          (relLeaves['reliability.push_wake_success_pct_doze_90s']!['cap']
                  as num)
              .toDouble();
      expect(nonDoze, greaterThan(doze));
    });

    // §17.5.4
    test('transcript signature verify cap ≥ 99.99 %', () {
      final leaf =
          relLeaves['reliability.transcript_signature_verify_success_pct']!;
      expect(leaf['cap'], equals(99.99));
      expect(leaf['cap_type'], equals('min'));
    });

    // §17.5.5
    test('recovery unwrap success cap ≥ 99.5 %', () {
      final leaf = relLeaves['reliability.recovery_unwrap_success_pct']!;
      expect(leaf['cap'], equals(99.5));
      expect(leaf['cap_type'], equals('min'));
    });

    // §17.5.6
    test('kill-switch propagation P99 cap ≤ 10 min', () {
      final leaf =
          relLeaves['reliability.kill_switch_propagation_p99_minutes']!;
      expect(leaf['cap'], equals(10));
      expect(leaf['cap_type'], equals('max'));
    });

    test('all min-type baselines are above their caps', () {
      for (final entry in relLeaves.entries.where(
        (e) => e.value['cap_type'] == 'min',
      )) {
        expect(
          (entry.value['baseline'] as num).toDouble(),
          greaterThanOrEqualTo((entry.value['cap'] as num).toDouble()),
          reason: '${entry.key} baseline below minimum cap',
        );
      }
    });

    test('max-type baselines are within their caps', () {
      for (final entry in relLeaves.entries.where(
        (e) => e.value['cap_type'] == 'max',
      )) {
        expect(
          (entry.value['baseline'] as num).toDouble(),
          lessThanOrEqualTo((entry.value['cap'] as num).toDouble()),
          reason: '${entry.key} baseline exceeds cap',
        );
      }
    });
  });
}
