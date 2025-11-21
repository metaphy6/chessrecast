import 'dart:math';
import '../../board/board.dart';
import '../../board/moves/move.dart';
import '../../board/moves/position.dart';
import '../../board/items/piece_type.dart';
import '../../board/items/piece_color.dart';
import '../../debug.dart';
import 'chess_bot.dart';

/// Smart bot that evaluates moves using chess heuristics
/// without deep search (won't block UI)
class GreedyBot extends ChessBot {
  final Random _random = Random();
  final int thinkingDelayMs;

  GreedyBot({
    required super.name,
    required super.color,
    this.thinkingDelayMs = 100,
  });

  @override
  String get description => 'Smart tactical player';

  /// Standard chess piece values
  static const _pieceValues = {
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.queen: 900,
    PieceType.king: 20000,
  };

  /// Center squares (d4, d5, e4, e5)
  static const _centerSquares = [
    Position(3, 3), // d4
    Position(3, 4), // e4
    Position(4, 3), // d5
    Position(4, 4), // e5
  ];

  /// Extended center squares
  static const _extendedCenterSquares = [
    Position(2, 2), // c3
    Position(2, 3), // d3
    Position(2, 4), // e3
    Position(2, 5), // f3
    Position(3, 2), // c4
    Position(3, 5), // f4
    Position(4, 2), // c5
    Position(4, 5), // f5
    Position(5, 2), // c6
    Position(5, 3), // d6
    Position(5, 4), // e6
    Position(5, 5), // f6
  ];

  @override
  Future<ChessMove?> selectMove(
    ChessBoard board,
    List<ChessMove> validMoves,
  ) async {
    if (validMoves.isEmpty) {
      logBot(name, 'No valid moves available');
      return null;
    }

    // Evaluate all moves and find the best one
    int bestScore = -999999;
    final List<ChessMove> bestMoves = [];

    for (final move in validMoves) {
      final score = _evaluateMove(board, move);

      if (score > bestScore) {
        bestScore = score;
        bestMoves.clear();
        bestMoves.add(move);
      } else if (score == bestScore) {
        // Keep all moves with the same best score
        bestMoves.add(move);
      }
    }

    // Pick randomly from best moves (adds variety)
    final selectedMove = bestMoves[_random.nextInt(bestMoves.length)];

    logBot(
      name,
      'Selected: ${selectedMove.from.algebraic}→${selectedMove.to.algebraic} (score: $bestScore)${selectedMove.capturedPiece != null ? ' captures ${selectedMove.capturedPiece!.type}' : ''}',
    );

    await Future.delayed(Duration(milliseconds: thinkingDelayMs));
    return selectedMove;
  }

  /// Evaluate a single move using chess heuristics
  /// This is fast (no recursion) and won't block the UI
  int _evaluateMove(ChessBoard board, ChessMove move) {
    int score = 0;

    // 1. Material: Capture value
    if (move.capturedPiece != null) {
      score += _pieceValues[move.capturedPiece!.type] ?? 0;
    }

    // 2. Promotion bonus
    if (move.isPromotion && move.promotionPiece != null) {
      // promotionPiece is a string, we'll give a fixed high bonus
      score += 700; // Big bonus for promoting (roughly queen value)
    }

    // 3. Center control
    if (_centerSquares.contains(move.to)) {
      score += 30;
    } else if (_extendedCenterSquares.contains(move.to)) {
      score += 10;
    }

    // 4. Piece development (move knights and bishops early)
    if (move.piece.type == PieceType.knight ||
        move.piece.type == PieceType.bishop) {
      // Bonus for developing pieces from starting positions
      final isStartingRank =
          (move.piece.color == PieceColor.white && move.from.row == 0) ||
          (move.piece.color == PieceColor.black && move.from.row == 7);
      if (isStartingRank) {
        score += 20;
      }
    }

    // 5. Pawn advancement
    if (move.piece.type == PieceType.pawn) {
      final advancement = move.piece.color == PieceColor.white
          ? move.to.row - move.from.row
          : move.from.row - move.to.row;
      score += advancement * 5; // Small bonus per rank advanced

      // Bonus for pawns reaching 6th/7th rank
      if ((move.piece.color == PieceColor.white && move.to.row >= 5) ||
          (move.piece.color == PieceColor.black && move.to.row <= 2)) {
        score += 20;
      }
    }

    // 6. Castling bonus
    if (move.isCastling) {
      score += 50;
    }

    // 7. King safety penalty (don't move king too early)
    if (move.piece.type == PieceType.king && !move.isCastling) {
      score -= 15;
    }

    // 8. Don't move the same piece twice in opening
    // (simple heuristic: if few pieces developed, prefer different pieces)
    final developedPieces = board.pieces.where((p) {
      if (p.color != move.piece.color) return false;
      if (p.type == PieceType.pawn || p.type == PieceType.king) return false;

      final startingRank = p.color == PieceColor.white ? 0 : 7;
      return p.position.row != startingRank;
    }).length;

    if (developedPieces < 4 && board.moveHistory.isNotEmpty) {
      final lastMove = board.moveHistory.last;
      if (lastMove.piece.position == move.from &&
          lastMove.piece.color == move.piece.color) {
        score -= 10; // Small penalty for moving same piece again
      }
    }

    return score;
  }
}
