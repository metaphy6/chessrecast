import '../../../board/utils/exporter.dart';

/// Cache for position evaluations to avoid recomputing
class PositionCache {
  static const int maxCacheSize = 10000;

  final Map<String, CacheEntry> _cache = {};

  /// Get cached evaluation for a position
  int? getEvaluation(ChessBoard board) {
    final key = _getBoardKey(board);
    final entry = _cache[key];

    if (entry == null) return null;

    // Simple LRU: update access time
    entry.lastAccessed = DateTime.now();
    return entry.evaluation;
  }

  /// Store evaluation in cache
  void storeEvaluation(ChessBoard board, int evaluation) {
    final key = _getBoardKey(board);

    // If cache is full, remove oldest entry
    if (_cache.length >= maxCacheSize) {
      _removeOldestEntry();
    }

    _cache[key] = CacheEntry(
      evaluation: evaluation,
      lastAccessed: DateTime.now(),
    );
  }

  /// Clear the cache
  void clear() {
    _cache.clear();
  }

  /// Get cache statistics
  Map<String, int> getStats() {
    return {'size': _cache.length, 'maxSize': maxCacheSize};
  }

  /// Remove oldest entry (LRU eviction)
  void _removeOldestEntry() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      if (oldestTime == null || entry.value.lastAccessed.isBefore(oldestTime)) {
        oldestTime = entry.value.lastAccessed;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  /// Get a simple board key for hashing
  String _getBoardKey(ChessBoard board) {
    final buffer = StringBuffer();

    // Encode piece positions
    for (int row = 7; row >= 0; row--) {
      int emptyCount = 0;
      for (int col = 0; col < 8; col++) {
        final piece = board.getPieceAt(Position(row, col));
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          buffer.write(piece.fenSymbol);
        }
      }
      if (emptyCount > 0) buffer.write(emptyCount);
      if (row > 0) buffer.write('/');
    }

    // Add current player
    buffer.write(' ${board.currentPlayer == PieceColor.white ? 'w' : 'b'}');

    return buffer.toString();
  }
}

/// Cache entry with LRU tracking
class CacheEntry {
  final int evaluation;
  DateTime lastAccessed;

  CacheEntry({required this.evaluation, required this.lastAccessed});
}


