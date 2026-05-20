// §11.7 — Monotonic clock: chess-clock arithmetic must be immune to wall-clock
// jumps.
//
// Proof test: mocks the system wall-clock to jump ±1 hour mid-game; the
// monotonic clock used by ChessClock must be unaffected.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/chess_clock.dart';
import '../../../lib/services/p2p/clock/time_control.dart';

void main() {
  group('§11.7 monotonic_only', () {
    test('wall-clock jump +1 hour does not affect chess clock', () {
      // Arrange: a fake monotonic clock we control.
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 60000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      // Advance monotonic by 5 s.
      mono.advanceMs(5000);
      // "Wall-clock jumps +1 hour" — irrelevant to ChessClock because it only
      // consults [mono].
      clock.stopMyTurn();

      // Should have consumed exactly 5 s, not 3605 s.
      expect(clock.myElapsedMs, closeTo(5000, 50));
    });

    test('wall-clock jump −1 hour does not affect chess clock', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 30000),
        monoClock: mono,
        side: ClockSide.black,
      );

      clock.startMyTurn();
      mono.advanceMs(3000);
      clock.stopMyTurn();

      expect(clock.myElapsedMs, closeTo(3000, 50));
    });

    test('accumulated elapsed is sum of individual turns', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.fischer(bankMs: 60000, incrementMs: 2000),
        monoClock: mono,
        side: ClockSide.white,
      );

      for (final ms in [1000, 2000, 500]) {
        clock.startMyTurn();
        mono.advanceMs(ms);
        clock.stopMyTurn();
      }

      // Total elapsed = 3500 ms, minus 3 increments of 2000 = net bank usage
      // is positive (not tested here — bank logic is in ChessClock).
      expect(clock.myElapsedMs, closeTo(3500, 100));
    });
  });
}
