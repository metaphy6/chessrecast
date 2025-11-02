import '../types/piece_color.dart';
import '../types/piece_type.dart';
import '../../modes/modes_enum.dart';
import 'position.dart';
import 'board.dart';

/// Extension for board query operations
extension BoardQueries on ChessBoard {
  /// Checks if the specified position is under attack by the specified color
  bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
    final attackingPieces = getPiecesOfColor(attackingColor);
    return attackingPieces.any((piece) {
      // In Save the Queen mode, prisoner queens cannot attack
      if (gameType == ModesEnum.saveTheQueen && piece.type == PieceType.queen) {
        // Check if queen is in opponent's half (still a prisoner)
        final isInOwnHalf = piece.color == PieceColor.white
            ? piece.position.row <=
                  3 // White's own half is rows 0-3
            : piece.position.row >= 4; // Black's own half is rows 4-7

        if (!isInOwnHalf) {
          return false; // Prisoner queens (in opponent's half) cannot give check or attack
        }
      }

      // Special handling for Royal Pawns mode - pawns attack like kings
      if (gameType == ModesEnum.royalPawns && piece.type == PieceType.pawn) {
        return _canPawnAttackLikeKingInRoyalPawnsMode(piece.position, position);
      }

      // Special handling for Diamonds mode bishops
      if (gameType == ModesEnum.diamonds && piece.type == PieceType.bishop) {
        return _canBishopAttackInDiamondsMode(piece.position, position);
      }
      return piece.canAttack(position, pieces);
    });
  }

  /// Checks if a pawn can attack a position in Royal Pawns mode (like a king)
  bool _canPawnAttackLikeKingInRoyalPawnsMode(
    Position pawnPos,
    Position targetPos,
  ) {
    final dx = (targetPos.col - pawnPos.col).abs();
    final dy = (targetPos.row - pawnPos.row).abs();
    // King-like attack: one square in any direction
    return dx <= 1 && dy <= 1 && (dx != 0 || dy != 0);
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
