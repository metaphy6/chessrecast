import 'package:flutter/foundation.dart';

import '../board/board.dart';
import '../board/moves/move.dart';
import '../management/orchestrator.dart';
import 'native.dart';
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
  easy, // depth 3,  200ms,  skill 0
  medium, // depth 5,  500ms,  skill 1
  hard, // depth 7,  1500ms, skill 3
  expert, // depth 10, 3000ms, skill 4
  maximum; // depth 64, 5000ms, skill 4

  int get maxDepth {
    switch (this) {
      case easy:
        return 3;
      case medium:
        return 5;
      case hard:
        return 7;
      case expert:
        return 10;
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

  int get skillLevel {
    switch (this) {
      case easy:
        return 0;
      case medium:
        return 1;
      case hard:
        return 3;
      case expert:
        return 4;
      case maximum:
        return 4;
    }
  }
}

class ChessEngine {
  ChessEngine();

  /// Find the best move for the current position.
  ///
  /// Runs the alpha-beta search on a background isolate via [compute]
  /// so the UI stays responsive.  Returns the full [SearchResult].
  Future<SearchResult> findBestMove(
    ChessBoard board, {
    EngineLevel level = EngineLevel.hard,
    int? timeLimitMs,
    int? maxDepth,
  }) {
    final timeMs = timeLimitMs ?? level.timeLimitMs;
    final depth = maxDepth ?? level.maxDepth;

    return compute(
      _runSearch,
      _SearchArgs(board, timeMs, depth, level.skillLevel),
    );
  }

  /// Find the best move AND apply it, all inside an isolate.
  ///
  /// Returns the search result together with the resulting board after the
  /// move has been executed and game status updated.  The caller only needs
  /// to do lightweight UI state assignment — zero heavy work on the main
  /// thread.
  Future<EngineMoveResult> computeEngineMove(
    ChessBoard board, {
    EngineLevel level = EngineLevel.hard,
  }) {
    return compute(
      _searchAndMove,
      _SearchArgs(board, level.timeLimitMs, level.maxDepth, level.skillLevel),
    );
  }
}

/// Result of [computeEngineMove] — bundles the search stats with the new board.
class EngineMoveResult {
  final SearchResult searchResult;
  final ChessBoard newBoard;
  const EngineMoveResult(this.searchResult, this.newBoard);
}

// ─── Isolate helpers (must be top-level for compute()) ───────────────────────

class _SearchArgs {
  final ChessBoard board;
  final int timeMs;
  final int depth;
  final int skillLevel;
  const _SearchArgs(this.board, this.timeMs, this.depth, this.skillLevel);
}

SearchResult _runSearch(_SearchArgs args) {
  final search = Search();
  return search.think(
    args.board,
    timeLimitMs: args.timeMs,
    maxDepth: args.depth,
  );
}

/// Search + execute move + update game status — all inside the isolate.
EngineMoveResult _searchAndMove(_SearchArgs args) {
  // Try native C engine first (works for all game modes: classic=0, mercenary=1).
  try {
    final native = NativeEngine();
    final sw = Stopwatch()..start();
    final nativeResult = native.findBestMoveSync(
      args.board,
      timeLimitMs: args.timeMs,
      maxDepth: args.depth,
      skillLevel: args.skillLevel,
    );
    sw.stop();
    debugPrint(
      '[NativeEngine] depth=${nativeResult.depth} '
      'score=${nativeResult.score} nodes=${nativeResult.nodesSearched} '
      'time=${sw.elapsedMilliseconds}ms mod=${args.board.gameType.name}',
    );
    if (nativeResult.bestMove != null) {
      final orchestrator = Orchestrator();
      final newBoard = orchestrator.executeMove(
        args.board,
        nativeResult.bestMove!,
      );
      return EngineMoveResult(nativeResult.toSearchResult(), newBoard);
    }
    // C engine found no legal moves – return immediately, don't fall
    // through to the Dart engine which may hang on this position.
    return EngineMoveResult(nativeResult.toSearchResult(), args.board);
  } catch (e) {
    debugPrint('[NativeEngine] unavailable, falling back to Dart: $e');
  }

  final search = Search();
  final result = search.think(
    args.board,
    timeLimitMs: args.timeMs,
    maxDepth: args.depth,
  );

  if (result.bestMove == null) {
    return EngineMoveResult(result, args.board);
  }

  // Execute the move and compute game status inside the isolate so the
  // main thread never blocks.
  final orchestrator = Orchestrator();
  final newBoard = orchestrator.executeMove(args.board, result.bestMove!);
  return EngineMoveResult(result, newBoard);
}
