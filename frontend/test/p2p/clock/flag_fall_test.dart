// §11.4 — Flag-fall consensus.
//
// When peer A's local view has peer B's clock at ≤0:
//   A emits BYE { result: timeout, victor: A, b_clock_at_my_view, my_clock_at_send }.
//   B verifies; if B agrees (within 200 ms tolerance), B counter-signs.
//   If B disagrees by more than tolerance: FLAG_FALL_DISAGREEMENT → MISMATCH.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/flag_fall.dart';
import '../../../lib/services/p2p/clock/chess_clock.dart';
import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/time_control.dart';

void main() {
  group('§11.4 flag_fall', () {
    late FakeMonotonicClock mono;

    setUp(() {
      mono = FakeMonotonicClock();
    });

    test('honest flag-fall: both peers agree', () {
      final myView = ClockView(remainingMs: -500, opponentRemainingMs: 30000);
      final opponentView =
          ClockView(remainingMs: -500, opponentRemainingMs: 30000);

      final result = FlagFallConsensus.evaluate(
        myView: myView,
        opponentView: opponentView,
        toleranceMs: 200,
      );
      expect(result, equals(FlagFallResult.agreed));
    });

    test('borderline: within 200 ms tolerance — agreed', () {
      final myView = ClockView(remainingMs: -100, opponentRemainingMs: 30000);
      // Opponent sees -300 ms (200 ms difference) — within tolerance.
      final opponentView =
          ClockView(remainingMs: -300, opponentRemainingMs: 30000);

      final result = FlagFallConsensus.evaluate(
        myView: myView,
        opponentView: opponentView,
        toleranceMs: 200,
      );
      expect(result, equals(FlagFallResult.agreed));
    });

    test('disagreement beyond tolerance: FLAG_FALL_DISAGREEMENT', () {
      final myView = ClockView(remainingMs: -100, opponentRemainingMs: 30000);
      // Opponent sees +500 ms (601 ms difference — beyond 200 ms tolerance).
      final opponentView =
          ClockView(remainingMs: 500, opponentRemainingMs: 30000);

      final result = FlagFallConsensus.evaluate(
        myView: myView,
        opponentView: opponentView,
        toleranceMs: 200,
      );
      expect(result, equals(FlagFallResult.disagreement));
    });

    test('both-flag-simultaneously: both peers report ≤0 — both lose', () {
      final myView = ClockView(remainingMs: -100, opponentRemainingMs: -50);
      final opponentView =
          ClockView(remainingMs: -50, opponentRemainingMs: -100);

      final result = FlagFallConsensus.evaluate(
        myView: myView,
        opponentView: opponentView,
        toleranceMs: 200,
      );
      expect(result, equals(FlagFallResult.bothFlagged));
    });

    test('ChessClock detects flag-fall when bank runs to zero', () {
      final clock = ChessClock(
        timeControl: TimeControl.suddenDeath(bankMs: 2000),
        monoClock: mono,
        side: ClockSide.white,
      );

      clock.startMyTurn();
      mono.advanceMs(2001); // 1 ms over bank.
      clock.stopMyTurn();

      expect(clock.hasFlagged, isTrue);
      expect(clock.remainingBankMs, isNegative);
    });
  });
}
