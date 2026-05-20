// §11.5 — Stability: clock arithmetic uses signed i64 ms with explicit clamp;
// clock never goes negative on local view.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/chess_clock.dart';
import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/time_control.dart';

void main() {
  group('§11.5 arithmetic_safety', () {
    test('remainingBankMs never overflows i64', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        // Maximum reasonable bank: 24 h in ms fits in i64.
        timeControl: TimeControl.suddenDeath(bankMs: 86400000),
        monoClock: mono,
        side: ClockSide.white,
      );
      expect(clock.remainingBankMs, equals(86400000));
      clock.startMyTurn();
      mono.advanceMs(1);
      clock.stopMyTurn();
      expect(clock.remainingBankMs, equals(86399999));
    });

    test('elapsed never goes negative — clamp at 0', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 60000),
        monoClock: mono,
        side: ClockSide.white,
      );
      // stopMyTurn without startMyTurn — elapsed should be 0, not negative.
      clock.stopMyTurn();
      expect(clock.myElapsedMs, greaterThanOrEqualTo(0));
    });

    test('remainingBankMs can go negative (hasFlagged) but stays finite', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 1000),
        monoClock: mono,
        side: ClockSide.white,
      );
      clock.startMyTurn();
      mono.advanceMs(2000);
      clock.stopMyTurn();

      // Negative is allowed on the local view after flag-fall.
      expect(clock.remainingBankMs, isNot(isNaN));
      expect(clock.remainingBankMs.isFinite, isTrue);
      expect(clock.hasFlagged, isTrue);
    });

    test('Bronstein delay does not make remaining > initial bank', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.bronstein(bankMs: 30000, delayMs: 2000),
        monoClock: mono,
        side: ClockSide.white,
      );
      clock.startMyTurn();
      mono.advanceMs(500); // Within delay window — net charge is 0.
      clock.stopMyTurn();

      // Bank must be exactly initial (Bronstein: only charge over delay amount).
      expect(clock.remainingBankMs, equals(30000));
    });
  });
}
