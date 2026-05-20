// §9.7 T-P-007 — PRNG output must never enter the wire-protocol / state-hash path.
//
// Replay determinism requires that every value committed to the game transcript
// is deterministically derivable from the opening position + move list.  If any
// PRNG output leaks into the protocol layer, replays diverge.
library;

/// Tag that marks a value as having been produced by a PRNG.
///
/// Values tagged [PrngOrigin] must NEVER appear in any wire-frame field or
/// state-hash input that is replayed.
class PrngOrigin {
  final int rawValue;
  const PrngOrigin(this.rawValue);
}

/// A move result as it is handed from the engine to the protocol layer.
///
/// Must be fully deterministic: same position + move list → same result.
class ReplayCleanMove {
  /// UCI move string (e.g., "e2e4").
  final String uci;

  /// Evaluation score in centipawns (from alpha-beta; deterministic).
  final int evalCp;

  const ReplayCleanMove({required this.uci, required this.evalCp});
}

/// Check that no [PrngOrigin] values leaked into [moveSources].
///
/// [moveSources] is the list of objects that contributed to the engine's
/// move decision.  Returns the list of leaked PRNG values (must be empty).
List<PrngOrigin> detectPrngLeak(List<Object> moveSources) =>
    moveSources.whereType<PrngOrigin>().toList();

/// UCI pattern: exactly 4–5 chars matching [a-h][1-8][a-h][1-8][qrbn]?.
final _uciPattern = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');

/// Validate that an [ReplayCleanMove] carries no PRNG-tainted fields.
///
/// Returns false when the UCI string is non-deterministic (random bytes) or
/// the evalCp is outside the plausible centipawn range.
bool isCleanMove(ReplayCleanMove move) {
  if (!_uciPattern.hasMatch(move.uci)) return false;
  if (move.evalCp < -30000 || move.evalCp > 30000) return false;
  return true;
}
