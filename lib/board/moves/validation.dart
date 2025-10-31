import '../types/piece_color.dart';
import '../types/piece_type.dart';
import '../entities/position.dart';
import '../entities/piece.dart';
import '../entities/move.dart';
import '../entities/board.dart';
import '../entities/queries.dart';

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
  ChessBoard makeMoveForValidation(ChessMove move) {
    final newPieces = List<ChessPiece>.from(pieces);

    // Remove the moving piece from its current position
    newPieces.removeWhere((piece) => piece.position == move.from);

    // Remove captured piece if any
    if (move.capturedPiece != null) {
      if (move.isEnPassant) {
        // For en passant, remove the pawn that was captured
        newPieces.removeWhere((piece) => piece == move.capturedPiece);
      } else {
        newPieces.removeWhere((piece) => piece.position == move.to);
      }
    } else {}

    // Add the piece to its new position
    newPieces.add(move.piece.movedTo(move.to));

    // Handle castling in validation - move the rook as well
    if (move.isCastling) {
      final kingRow = move.from.row;
      final isKingside = move.to.col == 6; // g-file

      if (isKingside) {
        // Kingside castling: move rook from h-file to f-file
        final rook = getPieceAt(Position(kingRow, 7));
        if (rook != null) {
          newPieces.removeWhere(
            (piece) => piece.position == Position(kingRow, 7),
          );
          newPieces.add(rook.movedTo(Position(kingRow, 5))); // f-file
        }
      } else {
        // Queenside castling: move rook from a-file to d-file
        final rook = getPieceAt(Position(kingRow, 0));
        if (rook != null) {
          newPieces.removeWhere(
            (piece) => piece.position == Position(kingRow, 0),
          );
          newPieces.add(rook.movedTo(Position(kingRow, 3))); // d-file
        }
      }
    }

    // For validation, preserve the current en passant target
    final result = copyWith(
      pieces: newPieces,
      currentPlayer: currentPlayer.opposite,
      moveHistory: [...moveHistory, move],
      enPassantTarget: enPassantTarget, // Keep current en passant target
    );
    return result;
  }
}
