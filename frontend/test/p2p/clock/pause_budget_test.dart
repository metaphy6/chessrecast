// §11.3 — Authoritative-clock rule and clock pause windows.
//
// Each peer is authoritative on its own clock.
// Local clock starts when MOVE_ACK is decoded; stops when own MOVE is sent.
// Clocks pause during ICE disconnected/failed and on app backgrounding.
// Total pause budget: 5 minutes; over budget → NETWORK_LOST.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/chess_clock.dart';
import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/time_control.dart';

void main() {
  group('§11.3 pause_budget', () {
    test('clock charges only during startMyTurn..stopMyTurn interval', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 60000),
        monoClock: mono,
        side: ClockSide.white,
      );

      // Advance 5 s before starting turn — not charged.
      mono.advanceMs(5000);

      clock.startMyTurn();
      mono.advanceMs(3000);
      clock.stopMyTurn();

      // Only the 3 s inside the turn should be charged.
      expect(clock.myElapsedMs, closeTo(3000, 50));
    });

    test('pause during ICE disconnection freezes the clock', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 60000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      mono.advanceMs(2000);
      clock.pause(PauseReason.iceDisconnected);
      mono.advanceMs(5000); // 5 s of ICE disconnection — not charged.
      clock.resume();
      mono.advanceMs(1000);
      clock.stopMyTurn();

      // Only 2+1 = 3 s charged.
      expect(clock.myElapsedMs, closeTo(3000, 100));
    });

    test('total pause budget: 5 minutes; over budget causes NETWORK_LOST', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 600000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      clock.pause(PauseReason.iceDisconnected);
      // Exceed total pause budget of 5 min = 300000 ms.
      mono.advanceMs(300001);
      final result = clock.resume();
      expect(result, equals(ResumeResult.pauseBudgetExceeded));
    });

    test('pause budget: exactly 5 min is still OK', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 600000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      clock.pause(PauseReason.iceDisconnected);
      mono.advanceMs(300000); // Exactly 5 min.
      final result = clock.resume();
      expect(result, equals(ResumeResult.ok));
    });

    test('multiple pauses accumulate toward budget', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 600000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      // Two 2.5 min pauses = 5 min total → budget exceeded on second.
      clock.pause(PauseReason.iceDisconnected);
      mono.advanceMs(150000);
      clock.resume();

      clock.pause(PauseReason.appBackgrounded);
      mono.advanceMs(150001); // 1 ms over.
      final result = clock.resume();
      expect(result, equals(ResumeResult.pauseBudgetExceeded));
    });

    test('increment is added after move completes (Fischer)', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.fischer(bankMs: 60000, incrementMs: 5000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      mono.advanceMs(3000);
      clock.stopMyTurn(); // Should add +5000 ms increment.

      // Remaining bank = 60000 - 3000 + 5000 = 62000.
      expect(clock.remainingBankMs, closeTo(62000, 100));
    });
  });
}
