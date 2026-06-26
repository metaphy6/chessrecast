// Phase 17 §17.2.3 — Per-leg latency budgets.
//
// Separate proof tests so a regression localises to the offending leg.
// encode ≤ 1000 µs, encrypt-AAD ≤ 300 µs, decrypt-verify ≤ 300 µs,
// engine-validate ≤ 1000 µs, apply-state-hash ≤ 500 µs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Per-leg latency budgets (§17.2.3)', () {
    late Map<String, Map<String, dynamic>> legLeaves;

    setUpAll(() {
      final budgetFile = File('../bots/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'bots/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      legLeaves = {
        for (final l
            in (tree['leaves'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where(
                  (l) =>
                      (l['id'] as String).startsWith('perf.') &&
                      (l['id'] as String).endsWith('_p99_us'),
                ))
          l['id'] as String: l,
      };
    });

    test('5 per-leg leaves are present', () {
      expect(legLeaves.length, equals(5));
    });

    test('encode P99 cap ≤ 1000 µs', () {
      expect(legLeaves['perf.encode_p99_us']!['cap'], equals(1000));
      expect(legLeaves['perf.encode_p99_us']!['units'], equals('us'));
    });

    test('encrypt-AAD P99 cap ≤ 300 µs', () {
      expect(legLeaves['perf.encrypt_aad_p99_us']!['cap'], equals(300));
    });

    test('decrypt-verify P99 cap ≤ 300 µs', () {
      expect(legLeaves['perf.decrypt_verify_p99_us']!['cap'], equals(300));
    });

    test('engine-validate P99 cap ≤ 1000 µs', () {
      expect(legLeaves['perf.engine_validate_p99_us']!['cap'], equals(1000));
    });

    test('apply-state-hash P99 cap ≤ 500 µs', () {
      expect(legLeaves['perf.apply_state_hash_p99_us']!['cap'], equals(500));
    });

    test('all per-leg baselines within caps', () {
      for (final entry in legLeaves.entries) {
        expect(
          (entry.value['baseline'] as num).toDouble(),
          lessThanOrEqualTo((entry.value['cap'] as num).toDouble()),
          reason: '${entry.key} baseline exceeds cap',
        );
      }
    });
  });
}
