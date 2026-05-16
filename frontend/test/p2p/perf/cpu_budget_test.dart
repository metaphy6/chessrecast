// §4.4 Efficiency — CPU budget proxy test.
//
// Verifies the CPU budget constant is defined at 6% average over a 5-min
// synthetic session. Real measurement is done in a manual test; this CI
// test anchors the constant so regressions in the budget value are caught.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/rtt_budgets.dart';

void main() {
  group('CpuBudget §4.4 efficiency', () {
    test('maxCpuPercent is 6', () {
      expect(RttBudgets.maxCpuPercent, equals(6));
    });

    test('cpuMeasurementWindowMinutes is 5', () {
      expect(RttBudgets.cpuMeasurementWindowMinutes, equals(5));
    });

    test('batteryBudgetPercent is 4 (30-min game)', () {
      expect(RttBudgets.batteryBudgetPercent, equals(4));
    });
  });
}
