// §11.2 — Hard budget: delay_p95 > 1 s or |offset| drift > 500 ms ends as
// CLOCK_DESYNC_BEYOND_BUDGET.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/ntp_estimator.dart';

void main() {
  group('§11.2 desync_budget', () {
    test('delay_p95 under 1 s: within budget', () {
      final est = NtpEstimator();
      for (int i = 0; i < 30; i++) {
        // RTT 100 ms, delay = 100.
        est.recordSample(
          tSendMs: i * 5000,
          tRecvMs: i * 5000 + 50,
          tRespMs: i * 5000 + 50,
          tRespEchoMs: i * 5000 + 100,
        );
      }
      final budget = est.evaluateBudget();
      expect(budget, equals(DesyncBudgetResult.withinBudget));
    });

    test('delay_p95 over 1 s: CLOCK_DESYNC_BEYOND_BUDGET', () {
      final est = NtpEstimator();
      for (int i = 0; i < 30; i++) {
        // RTT 1500 ms (exceeds 1 s budget).
        est.recordSample(
          tSendMs: i * 5000,
          tRecvMs: i * 5000 + 750,
          tRespMs: i * 5000 + 750,
          tRespEchoMs: i * 5000 + 1500,
        );
      }
      final budget = est.evaluateBudget();
      expect(budget, equals(DesyncBudgetResult.clockDesyncBeyondBudget));
    });

    test('|offset| drift > 500 ms: CLOCK_DESYNC_BEYOND_BUDGET', () {
      final est = NtpEstimator();
      for (int i = 0; i < 30; i++) {
        // 600 ms offset (exceeds 500 ms budget); RTT 20 ms.
        // T1=0, T2=610 (remote+600), T3=610, T4=20.
        // offset = ((610-0)+(610-20))/2 = (610+590)/2 = 600.
        est.recordSample(
          tSendMs: i * 5000,
          tRecvMs: i * 5000 + 610,
          tRespMs: i * 5000 + 610,
          tRespEchoMs: i * 5000 + 20,
        );
      }
      final budget = est.evaluateBudget();
      expect(budget, equals(DesyncBudgetResult.clockDesyncBeyondBudget));
    });

    test('boundary: exactly 500 ms offset is within budget', () {
      final est = NtpEstimator();
      for (int i = 0; i < 30; i++) {
        // Exactly 500 ms offset; RTT 20 ms.
        est.recordSample(
          tSendMs: i * 5000,
          tRecvMs: i * 5000 + 510,
          tRespMs: i * 5000 + 510,
          tRespEchoMs: i * 5000 + 20,
        );
      }
      final budget = est.evaluateBudget();
      expect(budget, equals(DesyncBudgetResult.withinBudget));
    });
  });
}
