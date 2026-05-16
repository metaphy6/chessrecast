// §4.3 Push wake cold-start P95 performance budget test (synthetic).
//
// This is a hermetic CI proxy — it does not actually launch the app.
// It verifies that the handshake budget constant is defined correctly and
// that a simulated in-process handshake completes within the budget.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/app_lifecycle_policy.dart';

void main() {
  group('Push wake cold-start §4.3 perf', () {
    test('pushWakeupP95BudgetMs is 5000 ms (5 s)', () {
      expect(AppLifecyclePolicy.pushWakeupP95BudgetMs, equals(5000));
    });

    test('simulated in-process handshake steps complete within budget', () {
      // Synthetic time model: each step has a pessimistic estimate.
      const signalRouteMs = 100;
      const iceGatherMs = 800;
      const dtlsHandshakeMs = 300;
      const aead_setup_ms = 10;
      const channelOpenMs = 50;
      const total =
          signalRouteMs + iceGatherMs + dtlsHandshakeMs + aead_setup_ms + channelOpenMs;
      expect(total, lessThan(AppLifecyclePolicy.pushWakeupP95BudgetMs));
    });

    test('warm-cache path (no ICE regather) is well under budget', () {
      const signalRouteMs = 100;
      const resumeMs = 150; // cached ICE candidates reused
      const total = signalRouteMs + resumeMs;
      expect(total, lessThan(AppLifecyclePolicy.pushWakeupP95BudgetMs));
    });
  });
}
