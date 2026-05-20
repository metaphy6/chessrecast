/// Flag-fall consensus helpers for P2P chess.
///
/// §11.4 — When a peer's clock view indicates the opponent has flagged
/// (remaining ≤ 0), the local client sends a BYE message with both
/// clock values.  The opponent verifies; if their own view differs by
/// more than [toleranceMs] ms, they respond with FLAG_FALL_DISAGREEMENT
/// which triggers MISMATCH adjudication.
library flag_fall;

/// A local snapshot of both sides' clocks (remaining ms, signed).
class ClockView {
  /// This side's remaining bank (≤ 0 after flag-fall).
  final int remainingMs;

  /// Opponent's remaining bank as observed locally.
  final int opponentRemainingMs;

  const ClockView({
    required this.remainingMs,
    required this.opponentRemainingMs,
  });
}

/// Outcome of the flag-fall consensus check.
enum FlagFallResult {
  /// Both peers agree on who flagged (within tolerance).
  agreed,

  /// The two clock views differ by more than the tolerance.
  disagreement,

  /// Both peers' clocks are ≤ 0 simultaneously.
  bothFlagged,
}

/// Stateless helper that compares two peers' clock views.
class FlagFallConsensus {
  FlagFallConsensus._();

  /// Evaluate whether the flag-fall claim is agreed upon.
  ///
  /// Convention for [ClockView] fields:
  ///   • [ClockView.remainingMs]         — the flagging side's remaining bank.
  ///   • [ClockView.opponentRemainingMs] — the non-flagging side's remaining bank.
  ///
  /// [myView]       — the local peer's clock snapshot.
  /// [opponentView] — the opponent peer's clock snapshot (received via net).
  /// [toleranceMs]  — maximum allowed ms discrepancy (default 200 ms per §11.4).
  static FlagFallResult evaluate({
    required ClockView myView,
    required ClockView opponentView,
    int toleranceMs = 200,
  }) {
    // Both-flag: the sending view shows BOTH clocks at ≤ 0.
    if (myView.remainingMs <= 0 && myView.opponentRemainingMs <= 0) {
      return FlagFallResult.bothFlagged;
    }

    // Cross-check: both sides must agree on the flagging peer's clock and the
    // non-flagging peer's clock within tolerance.
    final flaggedDiff =
        (myView.remainingMs - opponentView.remainingMs).abs();
    final nonFlaggedDiff =
        (myView.opponentRemainingMs - opponentView.opponentRemainingMs).abs();

    if (flaggedDiff > toleranceMs || nonFlaggedDiff > toleranceMs) {
      return FlagFallResult.disagreement;
    }
    return FlagFallResult.agreed;
  }
}
