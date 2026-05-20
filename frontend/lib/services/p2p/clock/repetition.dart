/// Repetition tracker for three-fold and five-fold repetition detection.
///
/// §11.9 — Per FIDE rules:
///   • Three-fold repetition is *claimable* (the player may claim a draw).
///   • Five-fold repetition is *mandatory* — auto-draw without UX (FIDE 2014+).
///
/// Position identity is represented as a string hash (e.g. Zobrist key
/// encoded as hex) for compatibility with both the native engine and the
/// Dart-side game state.
library repetition;

/// Tracks position hash occurrences for repetition detection.
class RepetitionTracker {
  final Map<String, int> _counts = {};

  /// Record a position hash.
  void record(String hash) {
    _counts[hash] = (_counts[hash] ?? 0) + 1;
  }

  /// Number of times [hash] has been recorded.
  int countOf(String hash) => _counts[hash] ?? 0;

  /// True if [hash] has been recorded at least 3 times (three-fold).
  bool isThreeFold(String hash) => countOf(hash) >= 3;

  /// True if [hash] has been recorded at least 5 times (five-fold).
  bool isFiveFold(String hash) => countOf(hash) >= 5;

  /// True if a mandatory auto-draw is required (five-fold).
  bool isAutoDrawRequired(String hash) => isFiveFold(hash);

  /// Reset all state (for new game).
  void reset() => _counts.clear();
}
