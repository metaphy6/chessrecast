// §4.4 Performance — RTT budgets (synthetic CI proxy).
//
// Does NOT make real network calls. Verifies the budget constants are
// correctly defined so the dashboard alert rules are anchored to spec.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/rtt_budgets.dart';

void main() {
  group('RttBudgets §4.4 performance', () {
    test('direct P50 budget is 80 ms', () {
      expect(RttBudgets.directP50Ms, equals(80));
    });

    test('direct P95 budget is 200 ms', () {
      expect(RttBudgets.directP95Ms, equals(200));
    });

    test('TURN-relayed P95 budget is 350 ms', () {
      expect(RttBudgets.turnRelayedP95Ms, equals(350));
    });

    test('direct P50 is less than P95', () {
      expect(RttBudgets.directP50Ms, lessThan(RttBudgets.directP95Ms));
    });

    test('TURN-relayed P95 is greater than direct P95', () {
      expect(RttBudgets.turnRelayedP95Ms,
          greaterThan(RttBudgets.directP95Ms));
    });
  });
}
