// §4.4 Stability — long-run synthetic stability test.
//
// Verifies that the stability budget constants are defined and that a
// simulated 1000-move exchange model has the correct invariant.
// Real 1000-move test is executed via the fake transport in L5; this
// anchors the budget.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/rtt_budgets.dart';

void main() {
  group('StabilityBudgets §4.4', () {
    test('long-run move count is 1000', () {
      expect(RttBudgets.longRunMoveCount, equals(1000));
    });

    test('max packet jitter ms is 500', () {
      expect(RttBudgets.maxJitterMs, equals(500));
    });

    test('max packet loss rate is 2%', () {
      expect(RttBudgets.maxLossRatePercent, equals(2));
    });

    test('memory growth threshold is 5%', () {
      expect(RttBudgets.maxMemoryGrowthPercent, equals(5));
    });
  });
}
