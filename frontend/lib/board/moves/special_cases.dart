import '../pieces/piece_color.dart';
import '../pieces/piece_type.dart';
import '../../mods/mods_enum.dart';
import 'position.dart';
import '../board.dart';

extension SpecialCases on ChessBoard {
  /// Checks if the specified position is under attack by the specified color
  bool isPositionUnderAttack(Position position, PieceColor attackingColor) {
    final attackingPieces = getPiecesOfColor(attackingColor);
    return attackingPieces.any((piece) {
      // Heir Mod: Kings ALWAYS control adjacent squares vs opponent king
      // This ensures kings can never be adjacent regardless of check rule state
      if (gameType == ModsEnum.heir && piece.type == PieceType.king) {
        final targetPiece = getPieceAt(position);
        // If checking for king adjacency, always apply king control
        if (targetPiece != null && targetPiece.type == PieceType.king) {
          return piece.canAttack(position, pieces, gameType, false);
        }
      }

      // KINGS' BATTLE PHASE 1: Only pawns and kings can attack/control squares before First Blood
      // Kings and pawns follow classic chess rules between themselves
      if (gameType == ModsEnum.kingsBattle && !_hasKingsKillHappened()) {
        if (piece.type != PieceType.pawn && piece.type != PieceType.king) {
          return false; // Other pieces have no effect before First Blood
        }
      }

      // In Save the Queen Mod, prisoner queens cannot attack
      if (gameType == ModsEnum.saveTheQueen && piece.type == PieceType.queen) {
        // Check if queen is in opponent's half (still a prisoner)
        final isInOwnHalf = piece.color == PieceColor.white
            ? piece.position.row <=
                  3 // White's own half is rows 0-3
            : piece.position.row >= 4; // Black's own half is rows 4-7

        if (!isInOwnHalf) {
          return false; // Prisoner queens (in opponent's half) cannot give check or attack
        }
      }

      // Special handling for Mercenary Mod - pawns attack like kings
      if (gameType == ModsEnum.mercenary && piece.type == PieceType.pawn) {
        return _canPawnAttackLikeKingInMercenaryMode(piece.position, position);
      }

      return piece.canAttack(
        position,
        pieces,
        gameType,
        _hasKingsKillHappened(),
      );
    });
  }

  /// Helper to check if King's Kill has happened in Kings' Battle mode
  bool _hasKingsKillHappened() {
    for (final move in moveHistory) {
      if (move.piece.type == PieceType.king &&
          move.capturedPiece != null &&
          move.capturedPiece!.type == PieceType.pawn) {
        return true;
      }
      if (move.isPromotion) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a pawn can attack a position in Mercenary Mod (like a king)
  bool _canPawnAttackLikeKingInMercenaryMode(
    Position pawnPos,
    Position targetPos,
  ) {
    final dx = (targetPos.col - pawnPos.col).abs();
    final dy = (targetPos.row - pawnPos.row).abs();
    // King-like attack: one square in any direction
    return dx <= 1 && dy <= 1 && (dx != 0 || dy != 0);
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
