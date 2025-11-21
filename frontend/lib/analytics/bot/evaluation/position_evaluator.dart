import '../../../board/utils/exporter.dart';
import 'piece_square_tables.dart';

/// Comprehensive position evaluator with multiple factors
class PositionEvaluator {
  /// Standard chess piece values
  static const _pieceValues = {
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.queen: 900,
    PieceType.king: 20000,
  };

  /// Evaluate a chess position (positive = good for current player)
  static int evaluatePosition(ChessBoard board) {
    int score = 0;

    // Check if it's endgame
    final isEndgame = _isEndgame(board);

    // Material + Position evaluation
    for (final piece in board.pieces) {
      final pieceValue = _pieceValues[piece.type] ?? 0;
      final positionValue = PieceSquareTables.getPositionValue(
        piece.type,
        piece.position,
        piece.color,
        isEndgame,
      );

      final totalValue = pieceValue + positionValue;

      if (piece.color == board.currentPlayer) {
        score += totalValue;
      } else {
        score -= totalValue;
      }
    }

    // Bishop pair bonus
    score += _evaluateBishopPair(board);

    // Pawn structure
    score += _evaluatePawnStructure(board);

    // King safety (in middlegame)
    if (!isEndgame) {
      score += _evaluateKingSafety(board);
    }

    // Mobility bonus
    score += _evaluateMobility(board);

    return score;
  }

  /// Check if position is in endgame
  static bool _isEndgame(ChessBoard board) {
    // Endgame if queens are off or very few pieces
    final queens = board.pieces.where((p) => p.type == PieceType.queen).length;
    final totalPieces = board.pieces.length;

    return queens == 0 || totalPieces <= 12;
  }

  /// Evaluate bishop pair advantage
  static int _evaluateBishopPair(ChessBoard board) {
    int score = 0;

    final whiteBishops = board.pieces
        .where((p) => p.type == PieceType.bishop && p.isWhite)
        .length;
    final blackBishops = board.pieces
        .where((p) => p.type == PieceType.bishop && !p.isWhite)
        .length;

    if (whiteBishops >= 2) {
      score += board.currentPlayer == PieceColor.white ? 50 : -50;
    }
    if (blackBishops >= 2) {
      score += board.currentPlayer == PieceColor.black ? 50 : -50;
    }

    return score;
  }

  /// Evaluate pawn structure
  static int _evaluatePawnStructure(ChessBoard board) {
    int score = 0;

    final myPawns = board.pieces
        .where(
          (p) => p.type == PieceType.pawn && p.color == board.currentPlayer,
        )
        .toList();
    final enemyPawns = board.pieces
        .where(
          (p) => p.type == PieceType.pawn && p.color != board.currentPlayer,
        )
        .toList();

    // Doubled pawns penalty
    score -= _countDoubledPawns(myPawns) * 20;
    score += _countDoubledPawns(enemyPawns) * 20;

    // Isolated pawns penalty
    score -= _countIsolatedPawns(myPawns) * 15;
    score += _countIsolatedPawns(enemyPawns) * 15;

    // Passed pawns bonus
    score += _countPassedPawns(myPawns, enemyPawns) * 30;
    score -= _countPassedPawns(enemyPawns, myPawns) * 30;

    return score;
  }

  /// Count doubled pawns
  static int _countDoubledPawns(List<ChessPiece> pawns) {
    final fileCount = <int, int>{};
    for (final pawn in pawns) {
      fileCount[pawn.position.col] = (fileCount[pawn.position.col] ?? 0) + 1;
    }
    return fileCount.values.where((count) => count > 1).length;
  }

  /// Count isolated pawns
  static int _countIsolatedPawns(List<ChessPiece> pawns) {
    int count = 0;
    for (final pawn in pawns) {
      final hasNeighbor = pawns.any(
        (p) =>
            p != pawn &&
            (p.position.col == pawn.position.col - 1 ||
                p.position.col == pawn.position.col + 1),
      );
      if (!hasNeighbor) count++;
    }
    return count;
  }

  /// Count passed pawns
  static int _countPassedPawns(
    List<ChessPiece> myPawns,
    List<ChessPiece> enemyPawns,
  ) {
    int count = 0;
    for (final pawn in myPawns) {
      final isPassed = !enemyPawns.any((enemy) {
        // Check if enemy pawn can block or capture
        if ((enemy.position.col - pawn.position.col).abs() > 1) return false;

        if (pawn.isWhite) {
          return enemy.position.row > pawn.position.row;
        } else {
          return enemy.position.row < pawn.position.row;
        }
      });

      if (isPassed) count++;
    }
    return count;
  }

  /// Evaluate king safety
  static int _evaluateKingSafety(ChessBoard board) {
    int score = 0;

    final myKing = board.getKing(board.currentPlayer);
    final enemyKing = board.getKing(board.currentPlayer.opposite);

    if (myKing != null) {
      score += _getKingSafetyScore(myKing, board, true);
    }

    if (enemyKing != null) {
      score -= _getKingSafetyScore(enemyKing, board, false);
    }

    return score;
  }

  /// Get king safety score for a king
  static int _getKingSafetyScore(
    ChessPiece king,
    ChessBoard board,
    bool isOurs,
  ) {
    int safety = 0;

    // Pawn shield bonus
    final direction = king.isWhite ? 1 : -1;
    final frontSquares = [
      Position(king.position.row + direction, king.position.col - 1),
      Position(king.position.row + direction, king.position.col),
      Position(king.position.row + direction, king.position.col + 1),
    ];

    for (final pos in frontSquares) {
      if (!pos.isValid) continue;
      final piece = board.getPieceAt(pos);
      if (piece != null &&
          piece.type == PieceType.pawn &&
          piece.color == king.color) {
        safety += 10;
      }
    }

    // Penalty for exposed king
    final attackedSquares = _countAttackedSquaresAroundKing(
      king.position,
      board,
    );
    safety -= attackedSquares * 5;

    return safety;
  }

  /// Count squares around king under attack
  static int _countAttackedSquaresAroundKing(
    Position kingPos,
    ChessBoard board,
  ) {
    int count = 0;
    final king = board.getPieceAt(kingPos);
    if (king == null) return 0;

    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final pos = Position(kingPos.row + dr, kingPos.col + dc);
        if (!pos.isValid) continue;

        // Check if this square is under attack
        if (board.isPositionUnderAttack(pos, king.color.opposite)) {
          count++;
        }
      }
    }

    return count;
  }

  /// Evaluate mobility (number of legal moves)
  static int _evaluateMobility(ChessBoard board) {
    // This is expensive, so we'll use a simplified version
    // Just count pieces that can move
    int myMobility = 0;
    int enemyMobility = 0;

    for (final piece in board.pieces) {
      // Skip pawns and kings for speed
      if (piece.type == PieceType.pawn || piece.type == PieceType.king) {
        continue;
      }

      final mobility = _estimatePieceMobility(piece, board);

      if (piece.color == board.currentPlayer) {
        myMobility += mobility;
      } else {
        enemyMobility += mobility;
      }
    }

    return (myMobility - enemyMobility) * 5;
  }

  /// Estimate piece mobility (count attacked squares)
  static int _estimatePieceMobility(ChessPiece piece, ChessBoard board) {
    int count = 0;

    // Check a few key squares around the piece
    for (int dr = -2; dr <= 2; dr++) {
      for (int dc = -2; dc <= 2; dc++) {
        if (dr == 0 && dc == 0) continue;
        final pos = Position(piece.position.row + dr, piece.position.col + dc);
        if (!pos.isValid) continue;

        if (piece.canAttack(pos, board.pieces)) {
          count++;
        }
      }
    }

    return count;
  }
}
