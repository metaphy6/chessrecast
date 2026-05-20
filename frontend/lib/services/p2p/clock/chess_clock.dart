/// Chess clock with injectable monotonic clock, full pause budget, and
/// Bronstein / Fischer / byo-yomi support.
///
/// §11.3 — Authoritative-clock rule:
///   • The side whose turn it is charges their own clock.
///   • Only the active side's clock ticks; the other is frozen.
///   • A peer may request a pause (ICE disconnect, app backgrounded, resync).
///     Total accumulated pause time ≤ 5 min (300 000 ms); exceeding it yields
///     [ResumeResult.pauseBudgetExceeded].
///
/// §11.7 — No DateTime usage; all elapsed time comes from [MonotonicClock].
library chess_clock;

import 'monotonic_clock.dart';
import 'time_control.dart';

/// Which side of the board this clock tracks.
enum ClockSide { white, black }

/// Reason for requesting a pause.
enum PauseReason {
  iceDisconnected,
  appBackgrounded,
  resync,
}

/// Result of attempting to resume after a pause.
enum ResumeResult {
  ok,
  pauseBudgetExceeded,
}

/// Per-side chess clock.
///
/// Each player creates their own [ChessClock] instance; the opponent's
/// remaining time is tracked separately and is exchanged via protocol
/// messages.
class ChessClock {
  static const int _maxPauseBudgetMs = 5 * 60 * 1000; // 5 minutes.
  static const int _lowTimeThresholdMs = 4000; // 4 s (display badge).

  final TimeControl _tc;
  final MonotonicClock _mono;
  final ClockSide _side;

  // Remaining bank (signed — can go negative after flag-fall).
  int _remainingBankMs;

  // Elapsed during current turn (0 when not in a turn).
  int _turnStartMonoMs = 0;
  bool _inTurn = false;
  int _myElapsedMs = 0;

  // Pause tracking.
  bool _paused = false;
  int _pauseStartMonoMs = 0;
  int _totalPauseMs = 0;
  bool _wasInTurnAtPause = false;

  // Bronstein: time of turn start (to compute delay amount).
  int _bronsteindelayUsedMs = 0;

  ChessClock({
    required TimeControl timeControl,
    required MonotonicClock monoClock,
    required ClockSide side,
  })  : _tc = timeControl,
        _mono = monoClock,
        _side = side,
        _remainingBankMs = timeControl.bankMs {
    if (timeControl.kind != TcKind.none && !monoClock.isAvailable) {
      throw MonotonicClockUnavailableError();
    }
  }

  /// Whether this clock tracks a timed session (vs. correspondence).
  bool get isTimed => _tc.kind != TcKind.none;

  /// Begin charging this side's clock.
  void startMyTurn() {
    if (_paused) return;
    _turnStartMonoMs = _mono.elapsedMs;
    _bronsteindelayUsedMs = 0;
    _inTurn = true;
  }

  /// Stop charging this side's clock and apply any increment.
  void stopMyTurn() {
    if (!_inTurn) return;
    _inTurn = false;

    final elapsed = _mono.elapsedMs - _turnStartMonoMs;
    _myElapsedMs += elapsed.clamp(0, 1 << 53);

    switch (_tc.kind) {
      case TcKind.none:
        break; // Correspondence: no charge.

      case TcKind.suddenDeath:
        _remainingBankMs -= elapsed;

      case TcKind.fischer:
        _remainingBankMs -= elapsed;
        _remainingBankMs += _tc.incrementMs ?? 0;

      case TcKind.bronstein:
        final delay = _tc.delayMs ?? 0;
        final charged = (elapsed - delay).clamp(0, elapsed);
        _remainingBankMs -= charged;

      case TcKind.byoYomi:
        // Simplified: charge main time only (full byo-yomi period tracking
        // would need period state — handled at a higher layer).
        _remainingBankMs -= elapsed;
    }
  }

  /// Pause the clock (e.g. network ICE reconnect).
  void pause(PauseReason reason) {
    if (_paused) return;
    _wasInTurnAtPause = _inTurn;
    // Stop charging the current turn mid-move.
    if (_inTurn) {
      final elapsed = _mono.elapsedMs - _turnStartMonoMs;
      _myElapsedMs += elapsed.clamp(0, 1 << 53);
      if (_tc.kind == TcKind.suddenDeath) _remainingBankMs -= elapsed;
      _inTurn = false;
    }
    _pauseStartMonoMs = _mono.elapsedMs;
    _paused = true;
  }

  /// Resume the clock after a pause.
  ///
  /// Returns [ResumeResult.pauseBudgetExceeded] if the total accumulated
  /// pause time has exceeded 5 minutes.
  ResumeResult resume() {
    if (!_paused) return ResumeResult.ok;
    final pauseDuration = _mono.elapsedMs - _pauseStartMonoMs;
    _totalPauseMs += pauseDuration;
    _paused = false;

    if (_totalPauseMs > _maxPauseBudgetMs) {
      return ResumeResult.pauseBudgetExceeded;
    }

    // Restart the turn that was in progress before the pause.
    if (_wasInTurnAtPause) {
      _turnStartMonoMs = _mono.elapsedMs;
      _inTurn = true;
    }
    return ResumeResult.ok;
  }

  /// Whether this side's flag has fallen (bank exhausted).
  bool get hasFlagged => isTimed && _remainingBankMs < 0;

  /// Remaining bank in ms (may be negative after flag-fall).
  int get remainingBankMs {
    if (!isTimed) return 0;
    if (!_inTurn) return _remainingBankMs;
    // Live estimate during an active turn.
    final elapsed = _mono.elapsedMs - _turnStartMonoMs;
    switch (_tc.kind) {
      case TcKind.none:
        return 0;
      case TcKind.suddenDeath:
      case TcKind.fischer:
        return _remainingBankMs - elapsed;
      case TcKind.bronstein:
        final delay = _tc.delayMs ?? 0;
        final charged = (elapsed - delay).clamp(0, elapsed);
        return _remainingBankMs - charged;
      case TcKind.byoYomi:
        return _remainingBankMs - elapsed;
    }
  }

  /// Total elapsed ms charged to this side (monotonic, never decreases).
  int get myElapsedMs => _myElapsedMs.clamp(0, 1 << 53);

  /// True when remaining bank is < 5 s (low-time warning threshold).
  bool get isLowTime {
    if (!isTimed) return false;
    return remainingBankMs < _lowTimeThresholdMs;
  }

  ClockSide get side => _side;
}
