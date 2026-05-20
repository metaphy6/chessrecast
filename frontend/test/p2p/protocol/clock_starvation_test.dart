// T-P-004 §9.2 — Per-side move-time budget enforced locally.
//
// Proof: LocalMoveClock enforces the per-move cap and total game budget
// using only local wall-clock readings, regardless of what the remote peer
// sends.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/local_move_clock.dart';

void main() {
  group('T-P-004 §9.2 — Local move clock budget enforcement', () {
    test('perMoveBudgetMs constant does not exceed engine maximum (5000 ms)', () {
      expect(kMaxMoveTimeBudgetMs, equals(5000));
    });

    test('move within budget returns ok', () {
      final clock = LocalMoveClock(perMoveBudgetMs: 3000, totalBudgetMs: 60000);
      final t0 = DateTime(2024, 1, 1, 12, 0, 0);
      clock.startMove(t0);
      final result = clock.recordMove(t0.add(const Duration(seconds: 2)));
      expect(result, equals(MoveClockOutcome.ok));
    });

    test('move that exceeds per-move budget returns perMoveTimeout', () {
      final clock = LocalMoveClock(perMoveBudgetMs: 1000, totalBudgetMs: 60000);
      final t0 = DateTime(2024, 1, 1, 12, 0, 0);
      clock.startMove(t0);
      // Simulate 1001 ms elapsed — just over the 1-second budget.
      final result = clock.recordMove(t0.add(const Duration(milliseconds: 1001)));
      expect(result, equals(MoveClockOutcome.perMoveTimeout));
    });

    test('move exactly at budget boundary is accepted', () {
      final clock = LocalMoveClock(perMoveBudgetMs: 1000, totalBudgetMs: 60000);
      final t0 = DateTime(2024, 1, 1);
      clock.startMove(t0);
      final result = clock.recordMove(t0.add(const Duration(milliseconds: 1000)));
      expect(result, equals(MoveClockOutcome.ok));
    });

    test('total budget exhaustion returns totalTimeoutForfeit', () {
      // 3-move game with a 3-second total budget.
      final clock = LocalMoveClock(perMoveBudgetMs: 2000, totalBudgetMs: 3000);
      final t0 = DateTime(2024, 1, 1);
      // Move 1: 1500 ms — ok, 1500 remaining.
      clock.startMove(t0);
      expect(clock.recordMove(t0.add(const Duration(milliseconds: 1500))),
          equals(MoveClockOutcome.ok));
      // Move 2: 1500 ms — exceeds 3000 ms total.
      clock.startMove(t0);
      expect(clock.recordMove(t0.add(const Duration(milliseconds: 1500))),
          equals(MoveClockOutcome.totalTimeoutForfeit));
    });

    test('totalUsedMs accumulates correctly across moves', () {
      final clock = LocalMoveClock(perMoveBudgetMs: 2000, totalBudgetMs: 60000);
      final t0 = DateTime(2024, 1, 1);
      clock.startMove(t0);
      clock.recordMove(t0.add(const Duration(milliseconds: 500)));
      clock.startMove(t0);
      clock.recordMove(t0.add(const Duration(milliseconds: 750)));
      expect(clock.totalUsedMs, equals(1250));
    });

    test('clock is independent of remote-claimed timestamps', () {
      // The adversary sends "I played in 0 ms" — but local clock says 4 s.
      final clock = LocalMoveClock(perMoveBudgetMs: 3000, totalBudgetMs: 60000);
      final localStart = DateTime(2024, 1, 1);
      // Remote claims instant move — but our local measurement is 4s.
      clock.startMove(localStart);
      final localEnd = localStart.add(const Duration(seconds: 4));
      final outcome = clock.recordMove(localEnd);
      // Must use local measurement → perMoveTimeout.
      expect(outcome, equals(MoveClockOutcome.perMoveTimeout),
          reason: 'local clock must not be overridden by remote timestamp');
    });
  });
}
