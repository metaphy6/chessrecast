// Phase 17 §17.4.1 — RSS caps with per-isolate sub-budgets.
// Phase 17 §17.4.4 — Isolate-restart rate cap.
// Phase 17 §17.4.5 — Crash-free rate cap.
//
// Over hard RSS cap → BUDGET_BREACH_MEMORY (§10.6) + defensive eviction.
// Synthetic CI proxy: verifies caps are registered correctly in the budget tree.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Memory / stability budgets (§17.4.1 + §17.4.4 + §17.4.5)', () {
    late Map<String, Map<String, dynamic>> stabLeaves;

    setUpAll(() {
      final budgetFile = File('../bots/baselines/p2p_budgets.json');
      if (!budgetFile.existsSync()) {
        fail(
          'bots/baselines/p2p_budgets.json missing — implement §17.1 first',
        );
      }
      final tree =
          jsonDecode(budgetFile.readAsStringSync()) as Map<String, dynamic>;
      stabLeaves = {
        for (final l
            in (tree['leaves'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where((l) => (l['id'] as String).startsWith('stability.')))
          l['id'] as String: l,
      };
    });

    // §17.4.1 RSS leaves
    test('steady-state RSS cap ≤ 80 MB', () {
      expect(stabLeaves['stability.rss_steady_mb']!['cap'], equals(80));
      expect(stabLeaves['stability.rss_steady_mb']!['units'], equals('mb'));
    });

    test('handshake RSS cap ≤ 140 MB', () {
      expect(stabLeaves['stability.rss_handshake_mb']!['cap'], equals(140));
    });

    test('UI isolate RSS cap ≤ 24 MB', () {
      expect(stabLeaves['stability.rss_ui_isolate_mb']!['cap'], equals(24));
    });

    test('P2P isolate RSS cap ≤ 32 MB', () {
      expect(stabLeaves['stability.rss_p2p_isolate_mb']!['cap'], equals(32));
    });

    test('engine isolate RSS cap ≤ 16 MB', () {
      expect(stabLeaves['stability.rss_engine_isolate_mb']!['cap'], equals(16));
    });

    test('isolate RSS sum ≤ steady-state cap', () {
      final ui = (stabLeaves['stability.rss_ui_isolate_mb']!['cap'] as num)
          .toDouble();
      final p2p = (stabLeaves['stability.rss_p2p_isolate_mb']!['cap'] as num)
          .toDouble();
      final eng = (stabLeaves['stability.rss_engine_isolate_mb']!['cap'] as num)
          .toDouble();
      final total = (stabLeaves['stability.rss_steady_mb']!['cap'] as num)
          .toDouble();
      expect(
        ui + p2p + eng,
        lessThanOrEqualTo(total),
        reason:
            'isolate RSS caps sum ${ui + p2p + eng} MB exceeds steady cap $total MB',
      );
    });

    // §17.4.4
    test('isolate-restart rate cap ≤ 1 / million sessions', () {
      expect(
        stabLeaves['stability.isolate_restart_per_million_sessions']!['cap'],
        equals(1),
      );
    });

    // §17.4.5
    test('crash-free rate minimum cap is 99.95 %', () {
      final leaf = stabLeaves['stability.crash_free_pct_7d']!;
      expect(leaf['cap'], equals(99.95));
      expect(leaf['cap_type'], equals('min'));
    });

    test('crash-free baseline ≥ cap (min-type)', () {
      final leaf = stabLeaves['stability.crash_free_pct_7d']!;
      expect(
        (leaf['baseline'] as num).toDouble(),
        greaterThanOrEqualTo((leaf['cap'] as num).toDouble()),
      );
    });
  });
}
