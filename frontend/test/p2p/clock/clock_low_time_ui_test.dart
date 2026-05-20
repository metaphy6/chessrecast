// §11.4 borderline UX — when both peers' clocks are < 5 s, UI model exposes
// the estimated remaining time with an explicit net-delay badge.
//
// This is a logic-layer (model) test; it doesn't require a widget harness.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/chess_clock.dart';
import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/time_control.dart';
import '../../../lib/services/p2p/clock/ntp_estimator.dart';

void main() {
  group('§11.4 clock_low_time_ui', () {
    test('low-time threshold fires when remaining < 5 s', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 6000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      mono.advanceMs(1001); // consumed 1 s, 5 s left: borderline not active.
      expect(clock.isLowTime, isFalse);

      mono.advanceMs(1000); // now 4 s left.
      expect(clock.isLowTime, isTrue);
    });

    test('low-time badge includes estimated net delay from NTP estimator', () {
      final est = NtpEstimator();
      // Simulate 80 ms RTT.
      est.recordSample(
        tSendMs: 0,
        tRecvMs: 40,
        tRespMs: 40,
        tRespEchoMs: 80,
      );
      final delayMs = est.best.delayMs;
      expect(delayMs, closeTo(80, 10));
    });

    test('not low-time when remaining > 5 s', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 60000),
        monoClock: mono,
        side: ClockSide.white,
      );
      clock.startMyTurn();
      mono.advanceMs(1000);
      expect(clock.isLowTime, isFalse);
    });
  });
}
