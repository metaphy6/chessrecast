import '../board/board.dart';
import '../board/pieces/piece_type.dart';
import '../board/moves/move.dart';
import '../board/moves/execution.dart';
import '../board/moves/generation.dart';
import '../board/moves/special_cases.dart';
import '../board/game_status.dart';
import '../mods/mods_enum.dart';

import 'evaluation.dart';
import 'transposition.dart';
import 'move_ordering.dart';

// ─── Search ──────────────────────────────────────────────────────────────────
//
// Implements:
//  • Iterative Deepening — search depth 1, then 2, then 3, …
//    Always has a "best so far" move ready when time runs out.
//  • Alpha-Beta Pruning — cuts huge branches of the game tree.
//  • Quiescence Search — extends captures/checks past the horizon
//    to avoid the "horizon effect" (missing obvious tactics).
//  • Null Move Pruning — skip a turn to quickly prove a position
//    is so good we can prune.
//  • Late Move Reductions (LMR) — search late-ordered quiet moves
//    at reduced depth; re-search at full depth if they look good.

/// Result returned by the search.
class SearchResult {
  final ChessMove? bestMove;
  final int score;
  final int depth;
  final int nodesSearched;

  const SearchResult({
    this.bestMove,
    required this.score,
    required this.depth,
    required this.nodesSearched,
  });

  @override
  String toString() =>
      'depth=$depth score=$score nodes=$nodesSearched move=$bestMove';
}

class Search {
  final TranspositionTable _tt;
  final MoveOrderer _orderer;

  int _nodes = 0;
  bool _stopped = false;
  late DateTime _deadline;

  // Best move from completed iterations (always available)
  ChessMove? _bestRootMove;

  Search({TranspositionTable? tt, MoveOrderer? orderer})
    : _tt = tt ?? TranspositionTable(sizeMB: 4),
      _orderer = orderer ?? MoveOrderer();

  /// Run an iterative-deepening search with a time limit.
  SearchResult think(
    ChessBoard board, {
    required int timeLimitMs,
    int? maxDepth,
  }) {
    _stopped = false;
    _nodes = 0;
    _bestRootMove = null;
    _deadline = DateTime.now().add(Duration(milliseconds: timeLimitMs));

    final depthLimit = maxDepth ?? 64;
    var lastCompleted = SearchResult(score: 0, depth: 0, nodesSearched: 0);

    for (var depth = 1; depth <= depthLimit; depth++) {
      final score = _alphaBetaRoot(board, depth);

      if (_stopped) break; // Time's up — use the last completed iteration

      if (_bestRootMove != null) {
        lastCompleted = SearchResult(
          bestMove: _bestRootMove,
          score: score,
          depth: depth,
          nodesSearched: _nodes,
        );
      }

      // If we found a forced mate, no need to search deeper
      if (isMateScore(score)) break;
    }

    return lastCompleted;
  }

  /// Immediately stop the search (can be called from another isolate/timer).
  void stop() => _stopped = true;

  void clearState() {
    _tt.clear();
    _orderer.clear();
  }

  // ── Root Alpha-Beta ──────────────────────────────────────────────────────

  int _alphaBetaRoot(ChessBoard board, int depth) {
    final moves = _generateAllMoves(board);
    if (moves.isEmpty) {
      return _isInCheck(board) ? -mateScore : 0;
    }

    // Order moves (use TT best from previous iteration)
    final ttEntry = _tt.probe(Zobrist.hash(board));
    _orderer.orderMoves(
      moves,
      board,
      ttBestMove: ttEntry?.bestMove ?? _bestRootMove,
      ply: 0,
    );

    var alpha = -infinity;
    final beta = infinity;
    ChessMove? bestMove;

    for (final move in moves) {
      final child = board.makeMove(move);
      final score = -_alphaBeta(child, depth - 1, -beta, -alpha, 1);

      if (_stopped) return alpha;

      if (score > alpha) {
        alpha = score;
        bestMove = move;
      }
    }

    if (bestMove != null) {
      _bestRootMove = bestMove;
    }

    return alpha;
  }

  // ── Alpha-Beta (interior nodes) ──────────────────────────────────────────

  int _alphaBeta(ChessBoard board, int depth, int alpha, int beta, int ply) {
    // Time check every 4096 nodes
    if ((_nodes & 4095) == 0 && DateTime.now().isAfter(_deadline)) {
      _stopped = true;
      return 0;
    }
    _nodes++;

    // Game-over detection: draws are set by makeMove (50-move, 3-fold),
    // mod-specific checkmates (e.g. Succession queen capture) are also set.
    if (board.gameStatus.isGameOver) {
      if (board.gameStatus == GameStatus.checkmate) {
        return -(mateScore - ply);
      }
      return 0; // stalemate or draw
    }

    final isMerc = board.gameType == ModsEnum.mercenary;

    // Transposition table probe
    final hash = Zobrist.hash(board);
    final ttEntry = _tt.probe(hash);
    if (ttEntry != null && ttEntry.depth >= depth) {
      if (ttEntry.flag == TTFlag.exact) return ttEntry.score;
      if (ttEntry.flag == TTFlag.lowerBound && ttEntry.score >= beta) {
        return ttEntry.score;
      }
      if (ttEntry.flag == TTFlag.upperBound && ttEntry.score <= alpha) {
        return ttEntry.score;
      }
    }

    // Leaf node → quiescence search
    if (depth <= 0) {
      return _quiescence(board, alpha, beta, ply);
    }

    final moves = _generateAllMoves(board);
    if (moves.isEmpty) {
      // makeMove doesn't set checkmate/stalemate — detect from check status.
      if (_isInCheck(board)) {
        return -(mateScore - ply); // Checkmate
      }
      return 0; // Stalemate
    }

    // Null-move pruning (skip when in check or few pieces left)
    if (!isMerc && depth >= 3 && !_isInCheck(board) && _hasMajorPieces(board)) {
      // Make a "null move" — pass the turn
      final nullBoard = _makeNullMove(board);
      final nullScore = -_alphaBeta(
        nullBoard,
        depth - 3,
        -beta,
        -beta + 1,
        ply + 1,
      );
      if (nullScore >= beta && !isMateScore(nullScore)) {
        return beta;
      }
    }

    // Order moves
    _orderer.orderMoves(moves, board, ttBestMove: ttEntry?.bestMove, ply: ply);

    final originalAlpha = alpha;
    var bestScore = -infinity;
    ChessMove? bestMove;
    var moveIndex = 0;

    for (final move in moves) {
      final child = board.makeMove(move);
      int score;

      // Late Move Reductions (LMR)
      if (!isMerc &&
          moveIndex >= 4 &&
          depth >= 3 &&
          !move.isCapture &&
          !move.isPromotion &&
          !_isInCheck(board)) {
        // Search with reduced depth first
        score = -_alphaBeta(child, depth - 2, -(alpha + 1), -alpha, ply + 1);
        // If it beats alpha, re-search at full depth
        if (score > alpha) {
          score = -_alphaBeta(child, depth - 1, -beta, -alpha, ply + 1);
        }
      } else {
        score = -_alphaBeta(child, depth - 1, -beta, -alpha, ply + 1);
      }

      if (_stopped) return 0;

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }

      if (score > alpha) {
        alpha = score;
      }

      if (alpha >= beta) {
        // Beta cutoff — record killer / history
        if (!move.isCapture) {
          _orderer.recordKiller(move, ply);
          _orderer.recordHistory(move, board.currentPlayer, depth);
        }
        break;
      }

      moveIndex++;
    }

    // Store in TT
    TTFlag flag;
    if (bestScore <= originalAlpha) {
      flag = TTFlag.upperBound;
    } else if (bestScore >= beta) {
      flag = TTFlag.lowerBound;
    } else {
      flag = TTFlag.exact;
    }

    _tt.store(
      hash: hash,
      depth: depth,
      score: bestScore,
      flag: flag,
      bestMove: bestMove,
    );

    return bestScore;
  }

  // ── Quiescence Search ────────────────────────────────────────────────────
  // Only explore captures (and promotions) past the main search horizon
  // to avoid evaluating "noisy" positions.

  int _quiescence(ChessBoard board, int alpha, int beta, int ply) {
    _nodes++;

    // Handle mod-specific game-overs (e.g., Succession queen capture)
    if (board.gameStatus.isGameOver) {
      if (board.gameStatus == GameStatus.checkmate) {
        return -(mateScore - ply);
      }
      return 0;
    }

    final inCheck = _isInCheck(board);

    // If in check, we MUST search all evasions (not just captures),
    // otherwise we'd miss checkmate.
    if (inCheck) {
      final evasions = _generateAllMoves(board);
      if (evasions.isEmpty) {
        return -(mateScore - ply); // Checkmate
      }
      _orderer.orderMoves(evasions, board, ply: ply);
      for (final move in evasions) {
        final child = board.makeMove(move);
        final score = -_quiescence(child, -beta, -alpha, ply + 1);
        if (score >= beta) return beta;
        if (score > alpha) alpha = score;
      }
      return alpha;
    }

    // Not in check: standPat evaluation
    final standPat = evaluate(board);
    if (standPat >= beta) return beta;
    if (standPat > alpha) alpha = standPat;

    // Generate only captures (and promotions)
    final captures = _generateCaptures(board);
    _orderer.orderMoves(captures, board, ply: ply);

    for (final move in captures) {
      final child = board.makeMove(move);
      final score = -_quiescence(child, -beta, -alpha, ply + 1);

      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }

    return alpha;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Generate all legal moves using the existing mod-aware move generation.
  List<ChessMove> _generateAllMoves(ChessBoard board) {
    final moves = <ChessMove>[];
    for (final piece in board.pieces) {
      if (piece.color == board.currentPlayer) {
        moves.addAll(board.getValidMovesFor(piece.position));
      }
    }
    return moves;
  }

  /// Generate only capture moves (for quiescence search).
  List<ChessMove> _generateCaptures(ChessBoard board) {
    final captures = <ChessMove>[];
    for (final piece in board.pieces) {
      if (piece.color == board.currentPlayer) {
        for (final move in board.getValidMovesFor(piece.position)) {
          if (move.isCapture || move.isPromotion) {
            captures.add(move);
          }
        }
      }
    }
    return captures;
  }

  bool _isInCheck(ChessBoard board) {
    try {
      return board.isKingInCheck(board.currentPlayer);
    } catch (_) {
      return false;
    }
  }

  bool _hasMajorPieces(ChessBoard board) {
    return board.pieces.any(
      (p) =>
          p.color == board.currentPlayer &&
          (p.type == PieceType.queen || p.type == PieceType.rook),
    );
  }

  /// Create a board with the side to move flipped (null-move).
  ChessBoard _makeNullMove(ChessBoard board) {
    return board.copyWith(
      currentPlayer: board.currentPlayer.opposite,
      enPassantTarget: null,
    );
  }
}
