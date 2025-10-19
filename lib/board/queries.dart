import 'enums/piece_color.dart';
import 'enums/piece_type.dart';
import 'enums/modes.dart';
import 'models/position.dart';
import 'models/board.dart';

/// Extension for board query operations
extension BoardQueries on ChessBoard {
  /// Checks if the specified position is under attack by the specified color
  bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
    final attackingPieces = getPiecesOfColor(attackingColor);
    return attackingPieces.any((piece) {
      // Special handling for Diamonds mode bishops
      if (gameType == GameType.diamonds && piece.type == PieceType.bishop) {
        return _canBishopAttackInDiamondsMode(piece.position, position);
      }
      return piece.canAttack(position, pieces);
    });
  }

  /// Checks if a bishop can attack a position in Diamonds mode (diamond pattern)
  bool _canBishopAttackInDiamondsMode(Position bishopPos, Position targetPos) {
    // Diamond pattern: 4 diagonal adjacent + 4 orthogonal 2-away
    final offsets = [
      // Diagonal adjacent (1 square away diagonally)
      [-1, -1], // top-left diagonal
      [-1, 1], // top-right diagonal
      [1, -1], // bottom-left diagonal
      [1, 1], // bottom-right diagonal
      // Orthogonal 2 squares away
      [-2, 0], // 2 up
      [0, 2], // 2 right
      [2, 0], // 2 down
      [0, -2], // 2 left
    ];

    for (final offset in offsets) {
      final pos = bishopPos.offset(offset[0], offset[1]);
      if (pos == targetPos) {
        return true;
      }
    }
    return false;
  }

  /// Checks if the king of the specified color is in check
  bool isKingInCheck(PieceColor kingColor) {
    final king = getKing(kingColor);
    if (king == null) {
      return false;
    }
    final inCheck = isPositionUnderAttack(king.position, kingColor.opposite);
    return inCheck;
  }
}
