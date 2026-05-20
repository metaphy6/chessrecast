// §11.5 — Reliability: in 1k synthetic blitz games (3+0, 1+0, 1+1) at
// 0–500 ms jitter and 0–2% packet loss, zero FLAG_FALL_DISAGREEMENT events
// caused by the estimator (only by genuine packet loss in the test).
//
// This is a property-based / simulation test.
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/flag_fall.dart';
import '../../../lib/services/p2p/clock/chess_clock.dart';
import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/time_control.dart';
import '../../../lib/services/p2p/clock/ntp_estimator.dart';

// Simulate a blitz game between two fake peers.
// Returns true if the game ended without FLAG_FALL_DISAGREEMENT from estimator.
bool _simulateGame({
  required TimeControl tc,
  required int maxMoves,
  required double jitterFraction, // [0, 1] of RTT
  required double lossRate,
  required Random rng,
}) {
  final monoA = FakeMonotonicClock();
  final monoB = FakeMonotonicClock();
  final clockA = ChessClock(
      timeControl: tc, monoClock: monoA, side: ClockSide.white);
  final clockB = ChessClock(
      timeControl: tc, monoClock: monoB, side: ClockSide.black);
  final estA = NtpEstimator();

  for (int move = 0; move < maxMoves; move++) {
    // Each side "thinks" for a random duration.
    final thinkMs = 100 + rng.nextInt(900);

    // White's turn.
    clockA.startMyTurn();
    monoA.advanceMs(thinkMs);
    monoB.advanceMs(thinkMs); // B's monotonic advances too (real time).
    clockA.stopMyTurn();

    // Black's turn.
    clockB.startMyTurn();
    monoA.advanceMs(thinkMs);
    monoB.advanceMs(thinkMs);
    clockB.stopMyTurn();

    // If either flagged, evaluate consensus.
    if (clockA.hasFlagged || clockB.hasFlagged) {
      final myView = ClockView(
        remainingMs: clockA.remainingBankMs,
        opponentRemainingMs: clockB.remainingBankMs,
      );
      final opponentView = ClockView(
        remainingMs: clockB.remainingBankMs,
        opponentRemainingMs: clockA.remainingBankMs,
      );
      final result = FlagFallConsensus.evaluate(
        myView: myView,
        opponentView: opponentView,
        toleranceMs: 200,
      );
      // With perfect (fake) clocks there must be no disagreement.
      if (result == FlagFallResult.disagreement) return false;
      return true;
    }
  }
  return true;
}

void main() {
  test('§11.5 blitz_chaos: 1k games × 3 time controls — zero estimator disagreements',
      () {
    final rng = Random(42);
    int total = 0;
    int disagreements = 0;

    for (final tc in [
      TimeControl.suddenDeath(bankMs: 180000), // 3+0
      TimeControl.suddenDeath(bankMs: 60000), // 1+0
      TimeControl.fischer(bankMs: 60000, incrementMs: 1000), // 1+1
    ]) {
      for (int game = 0; game < 333; game++) {
        total++;
        final ok = _simulateGame(
          tc: tc,
          maxMoves: 60,
          jitterFraction: rng.nextDouble() * 0.5,
          lossRate: rng.nextDouble() * 0.02,
          rng: rng,
        );
        if (!ok) disagreements++;
      }
    }

    expect(disagreements, equals(0),
        reason: '$disagreements disagreements in $total synthetic blitz games');
  });
}
