// §11.7 MONOTONIC_CLOCK_UNAVAILABLE — if the platform doesn't expose a
// monotonic clock, the app refuses to start any timed session.
// Untimed (correspondence) sessions remain possible.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/chess_clock.dart';
import '../../../lib/services/p2p/clock/time_control.dart';

void main() {
  group('§11.7 monotonic_unavailable', () {
    test('timed session is refused when monotonic clock is unavailable', () {
      final unavailableMono = UnavailableMonotonicClock();

      expect(
        () => ChessClock(
          timeControl: TimeControl.suddenDeath(bankMs: 60000),
          monoClock: unavailableMono,
          side: ClockSide.white,
        ),
        throwsA(isA<MonotonicClockUnavailableError>()),
      );
    });

    test('correspondence (untimed) session is allowed without monotonic clock',
        () {
      final unavailableMono = UnavailableMonotonicClock();

      // Should not throw — correspondence never needs the monotonic clock.
      final clock = ChessClock(
        timeControl: TimeControl.none(),
        monoClock: unavailableMono,
        side: ClockSide.white,
      );
      expect(clock.isTimed, isFalse);
    });

    test('available monotonic clock allows timed session', () {
      final mono = FakeMonotonicClock();
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 60000),
        monoClock: mono,
        side: ClockSide.white,
      );
      expect(clock.isTimed, isTrue);
    });
  });
}
