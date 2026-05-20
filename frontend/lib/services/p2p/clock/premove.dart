/// Premove queue for P2P chess.
///
/// §11.8 — A premove is a move queued by the local player during the
/// opponent's turn.  It is local-only until the opponent's move is
/// received; then the engine attempts to fire it.
///
/// Rules:
///   • At most one premove queued at a time (second enqueue replaces first).
///   • On opponent's move received, [PremoveQueue.tryFire] is called with a
///     [PremoveValidator] that checks legality in the new position.
///   • If illegal (e.g. due to mod phase change), the premove is discarded
///     and [PremoveFireResult.invalidated] is returned.
///   • If legal, the move is returned as a fired move and the queue cleared.
library premove;

/// A move expressed as UCI source/destination squares.
class PremoveMove {
  final String from;
  final String to;
  final String? promotion;

  const PremoveMove({required this.from, required this.to, this.promotion});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PremoveMove &&
        other.from == from &&
        other.to == to &&
        other.promotion == promotion;
  }

  @override
  int get hashCode => Object.hash(from, to, promotion);

  String toUci() {
    final promo = promotion ?? '';
    return '$from$to$promo';
  }

  @override
  String toString() => 'PremoveMove($from→$to${promotion != null ? "=$promotion" : ""})';
}

/// Result of attempting to fire a queued premove.
enum PremoveFireResult {
  /// The premove was legal and has been fired.
  fired,

  /// The premove was invalidated (illegal in the current position).
  invalidated,

  /// No premove was queued.
  noQueued,
}

/// Abstract legality checker injected into [PremoveQueue.tryFire].
abstract class PremoveValidator {
  /// Returns true iff [move] is legal in the current position.
  bool isLegal(PremoveMove move);

  /// The move that was last fired (for assertion in tests).
  PremoveMove? get lastFiredMove;
}

/// A fake validator for tests.
class FakePremoveValidator implements PremoveValidator {
  final bool _legal;
  final String? mod;
  PremoveMove? _lastFired;

  FakePremoveValidator({required bool isLegal, this.mod}) : _legal = isLegal;

  @override
  bool isLegal(PremoveMove move) => _legal;

  @override
  PremoveMove? get lastFiredMove => _lastFired;

  void _setFired(PremoveMove move) {
    _lastFired = move;
  }
}

/// Holds at most one queued premove.
class PremoveQueue {
  PremoveMove? _pending;

  /// Whether a premove is currently queued.
  bool get hasPremove => _pending != null;

  /// The queued premove (null if none).
  PremoveMove? get pendingMove => _pending;

  /// Queue [move] as the next premove.
  ///
  /// Replaces any previously queued premove.
  void enqueue(PremoveMove move) {
    _pending = move;
  }

  /// Attempt to fire the queued premove.
  ///
  /// Calls [validator.isLegal]; if legal, fires and clears the queue.
  /// If illegal, clears and returns [PremoveFireResult.invalidated].
  PremoveFireResult tryFire(PremoveValidator validator) {
    final move = _pending;
    if (move == null) return PremoveFireResult.noQueued;
    _pending = null;

    if (validator.isLegal(move)) {
      if (validator is FakePremoveValidator) {
        validator._setFired(move);
      }
      return PremoveFireResult.fired;
    }
    return PremoveFireResult.invalidated;
  }

  /// Cancel and clear the queued premove.
  void cancel() {
    _pending = null;
  }
}
