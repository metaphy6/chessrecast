// §9.2 T-P-004 — Per-side move-time budget enforced locally.
//
// Malicious peers may send moves at any pace; the local clock must enforce
// per-side time limits independently of what the remote peer claims.
//
// This module captures the constants and validation logic for the local
// move-clock enforcement layer.
library;

/// Maximum per-side time budget for a single move (ms) at any skill level.
///
/// This is a hard cap: even at `maximum` difficulty the engine will not be
/// allowed to think beyond this per the §P2P_PROTOCOL.md clock discipline.
const int kMaxMoveTimeBudgetMs = 5000;

/// Minimum per-side time budget (ms) — prevents trivially unfair settings.
const int kMinMoveTimeBudgetMs = 200;

/// Default per-game total time budget (ms) per side.
const int kDefaultGameTimeBudgetMs = 180000; // 3 minutes

/// Outcome from [LocalMoveClock.recordMove].
enum MoveClockOutcome {
  /// Move was within budget — game continues.
  ok,

  /// Move exceeded the per-move time cap → peer forfeits.
  perMoveTimeout,

  /// Player has exhausted their total game-time budget → forfeit.
  totalTimeoutForfeit,
}

/// A simple per-side local move clock.
///
/// All timing uses wall-clock elapsed since [startMove] was called, making
/// it immune to adversarial manipulation of the move timestamp sent over the
/// wire.
class LocalMoveClock {
  final int perMoveBudgetMs;
  final int totalBudgetMs;

  int _totalUsedMs = 0;
  DateTime? _moveStart;

  LocalMoveClock({
    this.perMoveBudgetMs = kMaxMoveTimeBudgetMs,
    this.totalBudgetMs = kDefaultGameTimeBudgetMs,
  })  : assert(perMoveBudgetMs >= kMinMoveTimeBudgetMs),
        assert(perMoveBudgetMs <= kMaxMoveTimeBudgetMs);

  /// Mark the start of a move.
  void startMove(DateTime now) {
    _moveStart = now;
  }

  /// Record move completion at [now].
  ///
  /// Returns [MoveClockOutcome.ok] when both per-move and total budgets are
  /// satisfied, or the appropriate forfeit reason otherwise.
  MoveClockOutcome recordMove(DateTime now) {
    final start = _moveStart;
    if (start == null) return MoveClockOutcome.ok;
    final elapsed = now.difference(start).inMilliseconds;
    _moveStart = null;

    if (elapsed > perMoveBudgetMs) return MoveClockOutcome.perMoveTimeout;

    _totalUsedMs += elapsed;
    if (_totalUsedMs >= totalBudgetMs) {
      return MoveClockOutcome.totalTimeoutForfeit;
    }
    return MoveClockOutcome.ok;
  }

  /// Total milliseconds consumed across all completed moves.
  int get totalUsedMs => _totalUsedMs;
}
