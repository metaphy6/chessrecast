import '../pieces/piece_color.dart';
import '../pieces/piece_type.dart';
import 'position.dart';
import '../piece.dart';
import 'move.dart';
import '../board.dart';
import 'special_cases.dart';
import 'helpers.dart';

/// Extension for move validation operations
extension MoveValidation on ChessBoard {
  /// Checks if kingside castling is possible for the given color
  bool canCastleKingside(PieceColor color) {
    final kingRow = color == PieceColor.white ? 0 : 7;
    final king = getKing(color);

    // King must be on starting square
    if (king == null || king.position != Position(kingRow, 4)) {
      return false;
    }

    // Rook must be on starting square
    final rook = getPieceAt(Position(kingRow, 7));
    if (rook == null || rook.type != PieceType.rook || rook.color != color) {
      return false;
    }

    // Squares between king and rook must be empty
    if (getPieceAt(Position(kingRow, 5)) != null ||
        getPieceAt(Position(kingRow, 6)) != null) {
      return false;
    }

    // King cannot be in check
    if (isKingInCheck(color)) {
      return false;
    }

    // King cannot pass through or land on attacked squares
    if (isPositionUnderAttack(Position(kingRow, 5), color.opposite) ||
        isPositionUnderAttack(Position(kingRow, 6), color.opposite)) {
      return false;
    }

    return true;
  }

  /// Checks if queenside castling is possible for the given color
  bool canCastleQueenside(PieceColor color) {
    final kingRow = color == PieceColor.white ? 0 : 7;
    final king = getKing(color);

    // King must be on starting square
    if (king == null || king.position != Position(kingRow, 4)) {
      return false;
    }

    // Rook must be on starting square
    final rook = getPieceAt(Position(kingRow, 0));
    if (rook == null || rook.type != PieceType.rook || rook.color != color) {
      return false;
    }

    // Squares between king and rook must be empty
    if (getPieceAt(Position(kingRow, 1)) != null ||
        getPieceAt(Position(kingRow, 2)) != null ||
        getPieceAt(Position(kingRow, 3)) != null) {
      return false;
    }

    // King cannot be in check
    if (isKingInCheck(color)) {
      return false;
    }

    // King cannot pass through or land on attacked squares
    if (isPositionUnderAttack(Position(kingRow, 2), color.opposite) ||
        isPositionUnderAttack(Position(kingRow, 3), color.opposite)) {
      return false;
    }

    return true;
  }

  /// Makes a move for validation purposes (preserves en passant target)
  /// Optimized to reduce allocations in hot path
  ChessBoard makeMoveForValidation(ChessMove move) {
    // Optimize: Pre-allocate list with known capacity
    final newPieces = List<ChessPiece>.of(pieces, growable: true);

    // Remove the moving piece from its current position (optimized loop)
    for (int i = newPieces.length - 1; i >= 0; i--) {
      if (newPieces[i].position == move.from) {
        newPieces.removeAt(i);
        break;
      }
    }

    // Remove captured piece if any
    if (move.capturedPiece != null) {
      if (move.isEnPassant) {
        // For en passant, remove the pawn that was captured
        for (int i = newPieces.length - 1; i >= 0; i--) {
          if (newPieces[i] == move.capturedPiece) {
            newPieces.removeAt(i);
            break;
          }
        }
      } else {
        for (int i = newPieces.length - 1; i >= 0; i--) {
          if (newPieces[i].position == move.to) {
            newPieces.removeAt(i);
            break;
          }
        }
      }
    }

    // Add the piece to its new position, including promotion state.
    var movedPiece = move.piece.movedTo(move.to);
    if (move.isPromotion && move.promotionPiece != null) {
      final promotedType = switch (move.promotionPiece!.toUpperCase()) {
        'Q' => PieceType.queen,
        'R' => PieceType.rook,
        'B' => PieceType.bishop,
        'N' => PieceType.knight,
        'K' => PieceType.king,
        _ => move.piece.type,
      };
      movedPiece = movedPiece.copyWith(type: promotedType);
    }
    newPieces.add(movedPiece);

    // Handle castling in validation - move the rook as well using helper
    if (move.isCastling) {
      performCastlingRookMove(newPieces, move.from, move.to);
    }

    // Include the test move in history so that unlocking captures
    // (king×pawn in Kings' Battle, pawn promotion) are visible to
    // isPositionUnderAttack.  This makes ALL enemy pieces contribute to
    // the attack map when validating the post-unlock position, preventing
    // the king from capturing a pawn defended by bishops/queens/etc.
    final result = copyWith(
      pieces: newPieces,
      currentPlayer: currentPlayer.opposite,
      moveHistory: [...moveHistory, move],
      enPassantTarget: enPassantTarget, // Keep current en passant target
    );
    return result;
  }
}
