/// Shared helpers for all *_position_probe.dart tools.
///
/// Import this file and remove the local copies of the functions listed below.
/// Each probe file keeps only its mod-specific `_buildBoard` and the public
/// `run*PositionProbe` entry point.
library;

import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/management/orchestrator.dart';

// ---------------------------------------------------------------------------
// Data class
// ---------------------------------------------------------------------------

class ProbeMove {
  final ChessMove move;
  final int score;
  final ChessMove? bestReply;

  const ProbeMove({
    required this.move,
    required this.score,
    required this.bestReply,
  });
}

// ---------------------------------------------------------------------------
// Move analysis
// ---------------------------------------------------------------------------

ProbeMove analyzeProbeMove(
  NativeEngine engine,
  Orchestrator orchestrator,
  ChessBoard board,
  ChessMove move, {
  required int timeMs,
  required int depth,
  int skillLevel = 4,
}) {
  final child = orchestrator.executeMove(board, move);
  final score = scoreProbeMove(
    engine,
    mover: board.currentPlayer,
    childBoard: child,
    referenceMs: timeMs,
    referenceDepth: depth,
    referenceSkill: skillLevel,
  );
  final bestReply = child.gameStatus.isGameOver
      ? null
      : (() {
          engine.resetState();
          return engine
              .findBestMoveSync(
                child,
                timeLimitMs: timeMs,
                maxDepth: math.max(1, depth - 1),
                skillLevel: skillLevel,
              )
              .bestMove;
        })();

  return ProbeMove(move: move, score: score, bestReply: bestReply);
}

/// Score a move by evaluating the child position from the mover's perspective.
///
/// Uses [mover] to determine sign: if the child board still belongs to the
/// same [mover] (e.g. a bonus-turn mod), the score is positive; otherwise it
/// is negated so that higher is always better for [mover].
int scoreProbeMove(
  NativeEngine engine, {
  required PieceColor mover,
  required ChessBoard childBoard,
  required int referenceMs,
  required int referenceDepth,
  int referenceSkill = 4,
}) {
  if (childBoard.gameStatus == GameStatus.checkmate) {
    return mateScore;
  }
  if (childBoard.gameStatus == GameStatus.draw ||
      childBoard.gameStatus == GameStatus.stalemate) {
    return 0;
  }

  engine.resetState();
  final reply = engine.findBestMoveSync(
    childBoard,
    timeLimitMs: referenceMs,
    maxDepth: math.max(1, referenceDepth - 1),
    skillLevel: referenceSkill,
  );
  return childBoard.currentPlayer == mover ? reply.score : -reply.score;
}

// ---------------------------------------------------------------------------
// Move notation
// ---------------------------------------------------------------------------

bool sameProbeMove(ChessMove a, ChessMove b) {
  return a.from == b.from &&
      a.to == b.to &&
      a.promotionPiece == b.promotionPiece;
}

String probeMoveLabel(ChessMove? move) {
  if (move == null) return '(none)';
  final piece = switch (move.piece.type) {
    PieceType.pawn => '',
    PieceType.knight => 'N',
    PieceType.bishop => 'B',
    PieceType.rook => 'R',
    PieceType.queen => 'Q',
    PieceType.king => 'K',
  };
  final capture = move.isCapture ? 'x' : '-';
  final promotion = move.isPromotion ? '=${move.promotionPiece}' : '';
  return '$piece${move.from.algebraic}$capture${move.to.algebraic}$promotion';
}

String probeCp(int score) {
  if (isMateScore(score)) {
    final mateIn = (mateScore - score.abs() + 1) ~/ 2;
    return score > 0 ? 'M$mateIn' : '-M$mateIn';
  }
  final cp = score / 100.0;
  return '${cp >= 0 ? '+' : ''}${cp.toStringAsFixed(2)}';
}

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

String? readProbeArg(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length);
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

int readProbeIntArg(List<String> args, String name, int fallback) {
  final value = readProbeArg(args, name);
  return value == null ? fallback : int.tryParse(value) ?? fallback;
}

// ---------------------------------------------------------------------------
// Move lookup from coordinate notation (e.g. "e2e4", "d7d8q")
// ---------------------------------------------------------------------------

ChessMove? parseCoordinateMove(
  Orchestrator orchestrator,
  ChessBoard board,
  String notation,
) {
  if (notation.length < 4) return null;

  final moves = orchestrator.getAllValidMoves(board);
  try {
    final from = Position.fromAlgebraic(notation.substring(0, 2));
    final to = Position.fromAlgebraic(notation.substring(2, 4));
    final promotion = notation.length >= 5
        ? notation.substring(4, 5).toUpperCase()
        : null;

    for (final move in moves) {
      if (move.from != from || move.to != to) continue;
      if (promotion != null && move.promotionPiece != promotion) continue;
      if (promotion == null && move.isPromotion) continue;
      return move;
    }
  } catch (_) {
    return null;
  }

  return null;
}
