import '../items/piece_color.dart';
import '../items/piece_type.dart';
import 'position.dart';
import '../piece.dart';
import 'move.dart';
import '../board.dart';
import 'special_cases.dart';
import 'helpers.dart';
import '../../modes/modes_enum.dart';

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

    // Add the piece to its new position
    newPieces.add(move.piece.movedTo(move.to));

    // Handle castling in validation - move the rook as well using helper
    if (move.isCastling) {
      performCastlingRookMove(newPieces, move.from, move.to);
    }

    // Handle teleport in validation - swap king and rook positions
    if (gameType == ModesEnum.teleport) {
      // King-initiated teleport
      if (move.piece.type == PieceType.king) {
        // Check if there's a friendly rook at the destination
        ChessPiece? rookAtDest;
        for (final p in pieces) {
          if (p.type == PieceType.rook &&
              p.color == move.piece.color &&
              p.position == move.to) {
            rookAtDest = p;
            break;
          }
        }

        if (rookAtDest != null) {
          // This is a teleport - remove the rook from destination and add it at king's old position
          newPieces.removeWhere(
            (p) => p.position == move.to && p.type == PieceType.rook,
          );
          newPieces.add(rookAtDest.movedTo(move.from));
        }
      }

      // Rook-initiated teleport
      if (move.piece.type == PieceType.rook) {
        // Check if there's a friendly king at the destination
        ChessPiece? kingAtDest;
        for (final p in pieces) {
          if (p.type == PieceType.king &&
              p.color == move.piece.color &&
              p.position == move.to) {
            kingAtDest = p;
            break;
          }
        }

        if (kingAtDest != null) {
          // This is a teleport - remove the king from destination and add it at rook's old position
          newPieces.removeWhere(
            (p) => p.position == move.to && p.type == PieceType.king,
          );
          newPieces.add(kingAtDest.movedTo(move.from));
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
