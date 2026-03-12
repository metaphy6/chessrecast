import 'dart:async';
import 'dart:isolate';

import '../board/board.dart';
import '../board/moves/move.dart';
import 'search.dart';

// ─── Chess Engine ────────────────────────────────────────────────────────────
//
// Public API that wraps the Search algorithm.  Provides:
//  • Async `findBestMove()` that runs search on a background isolate
//    so the UI never freezes.
//  • Configurable time limit and max depth.
//  • Optional callback for real-time search info.

/// Information emitted during search (for UI / debug display).
class SearchInfo {
  final int depth;
  final int score;
  final int nodes;
  final ChessMove? bestMove;
  final Duration elapsed;

  const SearchInfo({
    required this.depth,
    required this.score,
    required this.nodes,
    this.bestMove,
    required this.elapsed,
  });

  @override
  String toString() {
    final ms = elapsed.inMilliseconds;
    final nps = ms > 0 ? (nodes * 1000 ~/ ms) : 0;
    return 'depth $depth  score $score  nodes $nodes  nps $nps';
  }
}

/// Engine difficulty preset.
enum EngineLevel {
  easy, // depth 2,  200ms
  medium, // depth 4,  500ms
  hard, // depth 6,  1500ms
  expert, // depth 8,  3000ms
  maximum; // depth 64, 5000ms

  int get maxDepth {
    switch (this) {
      case easy:
        return 2;
      case medium:
        return 4;
      case hard:
        return 6;
      case expert:
        return 8;
      case maximum:
        return 64;
    }
  }

  int get timeLimitMs {
    switch (this) {
      case easy:
        return 200;
      case medium:
        return 500;
      case hard:
        return 1500;
      case expert:
        return 3000;
      case maximum:
        return 5000;
    }
  }
}

class ChessEngine {
  ChessEngine();

  /// Find the best move for the current position.
  ///
  /// Runs the alpha-beta search on a background isolate so the UI stays
  /// responsive.  Returns `null` only if there are no legal moves.
  Future<ChessMove?> findBestMove(
    ChessBoard board, {
    EngineLevel level = EngineLevel.hard,
    int? timeLimitMs,
    int? maxDepth,
  }) async {
    final timeMs = timeLimitMs ?? level.timeLimitMs;
    final depth = maxDepth ?? level.maxDepth;

    final result = await Isolate.run(() {
      final search = Search();
      return search.think(board, timeLimitMs: timeMs, maxDepth: depth);
    });

    return result.bestMove;
  }

  /// Synchronous version (blocks the calling thread).
  /// Use this only for testing or when running inside an isolate already.
  SearchResult findBestMoveSync(
    ChessBoard board, {
    EngineLevel level = EngineLevel.hard,
    int? timeLimitMs,
    int? maxDepth,
  }) {
    final timeMs = timeLimitMs ?? level.timeLimitMs;
    final depth = maxDepth ?? level.maxDepth;

    final search = Search();
    return search.think(board, timeLimitMs: timeMs, maxDepth: depth);
  }
}
