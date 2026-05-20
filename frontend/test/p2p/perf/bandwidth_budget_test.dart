// Phase 17 §17.3.3 — Bandwidth caps by sub-channel.
//
// chess ≤ 8 kbps, clock ≤ 1 kbps, per-spectator ≤ 16 kbps.
// Over-budget on chess → BACKPRESSURE_DROP; over-budget on chat → forced slow-mode.
// Synthetic CI proxy: verifies caps are registered correctly in the budget tree.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bandwidth budgets (§17.3.3)', () {
    late Map<String, Map<String, dynamic>> bwLeaves;

    setUpAll(() {
      final budgetFile = File('../agent/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'agent/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      bwLeaves = {
        for (final l
            in (tree['leaves'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where((l) => (l['id'] as String).contains('bandwidth')))
          l['id'] as String: l,
      };
    });

    test('three bandwidth leaves present', () {
      expect(bwLeaves.length, equals(3));
    });

    test('chess sub-channel cap ≤ 8 kbps', () {
      expect(
        bwLeaves['efficiency.bandwidth_chess_kbps_steady']!['cap'],
        equals(8),
      );
      expect(
        bwLeaves['efficiency.bandwidth_chess_kbps_steady']!['units'],
        equals('kbps'),
      );
    });

    test('clock sub-channel cap ≤ 1 kbps', () {
      expect(
        bwLeaves['efficiency.bandwidth_clock_kbps_steady']!['cap'],
        equals(1),
      );
    });

    test('per-spectator cap ≤ 16 kbps', () {
      expect(
        bwLeaves['efficiency.bandwidth_per_spectator_kbps_steady']!['cap'],
        equals(16),
      );
    });

    test('per-spectator cap > chess cap (spectators get fanout headroom)', () {
      final chess =
          (bwLeaves['efficiency.bandwidth_chess_kbps_steady']!['cap'] as num)
              .toDouble();
      final spec =
          (bwLeaves['efficiency.bandwidth_per_spectator_kbps_steady']!['cap']
                  as num)
              .toDouble();
      expect(spec, greaterThan(chess));
    });

    test('all bandwidth baselines within caps', () {
      for (final entry in bwLeaves.entries) {
        expect(
          (entry.value['baseline'] as num).toDouble(),
          lessThanOrEqualTo((entry.value['cap'] as num).toDouble()),
          reason: '${entry.key} baseline exceeds cap',
        );
      }
    });
  });
}
