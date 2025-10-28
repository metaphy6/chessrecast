import '../types/piece_type.dart';
import '../types/piece_color.dart';
import '../../modes/game_types.dart';
import '../entities/position.dart';
import '../entities/piece.dart';
import '../entities/move.dart';
import '../entities/board.dart';

/// Extension for move execution operations
extension MoveExecution on ChessBoard {
  /// Makes a move and returns a new board state (public method)
  ChessBoard makeMove(ChessMove move) {
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
    }

    // Add the piece to its new position
    if (move.isPromotion) {
      // Handle pawn promotion - create the promoted piece
      PieceType promotedType;
      switch (move.promotionPiece) {
        case 'Q':
          promotedType = PieceType.queen;
          break;
        case 'R':
          promotedType = PieceType.rook;
          break;
        case 'B':
          promotedType = PieceType.bishop;
          break;
        case 'N':
          promotedType = PieceType.knight;
          break;
        case 'K':
          promotedType = PieceType.king;
          break;
        default:
          promotedType = PieceType.queen; // Default fallback
      }

      newPieces.add(
        ChessPiece(
          type: promotedType,
          color: move.piece.color,
          position: move.to,
        ),
      );
    } else {
      // Regular move
      newPieces.add(move.piece.movedTo(move.to));
    }

    // Handle castling - move the rook as well
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

    // Determine en passant target for next turn
    Position? newEnPassantTarget;
    if (move.piece.type == PieceType.pawn) {
      // Check if this is a double pawn move
      final rowDiff = (move.to.row - move.from.row).abs();
      if (rowDiff == 2) {
        // Set en passant target to the square the pawn passed over
        final targetRow = (move.from.row + move.to.row) ~/ 2;
        newEnPassantTarget = Position(targetRow, move.from.col);
      } else {}
    } else {}

    // Update castling rights based on piece movements
    bool newWhiteCanCastleKingside = whiteCanCastleKingside;
    bool newWhiteCanCastleQueenside = whiteCanCastleQueenside;
    bool newBlackCanCastleKingside = blackCanCastleKingside;
    bool newBlackCanCastleQueenside = blackCanCastleQueenside;

    // Disable castling if king or rook moves
    if (move.piece.type == PieceType.king) {
      if (move.piece.color == PieceColor.white) {
        newWhiteCanCastleKingside = false;
        newWhiteCanCastleQueenside = false;
      } else {
        newBlackCanCastleKingside = false;
        newBlackCanCastleQueenside = false;
      }
    } else if (move.piece.type == PieceType.rook) {
      if (move.piece.color == PieceColor.white) {
        if (move.from == Position(0, 0)) {
          // a1 rook
          newWhiteCanCastleQueenside = false;
        } else if (move.from == Position(0, 7)) {
          // h1 rook
          newWhiteCanCastleKingside = false;
        }
      } else {
        if (move.from == Position(7, 0)) {
          // a8 rook
          newBlackCanCastleQueenside = false;
        } else if (move.from == Position(7, 7)) {
          // h8 rook
          newBlackCanCastleKingside = false;
        }
      }
    }

    // Also disable castling if rook is captured
    if (move.capturedPiece?.type == PieceType.rook) {
      if (move.to == Position(0, 0)) {
        // a1 rook captured
        newWhiteCanCastleQueenside = false;
      } else if (move.to == Position(0, 7)) {
        // h1 rook captured
        newWhiteCanCastleKingside = false;
      } else if (move.to == Position(7, 0)) {
        // a8 rook captured
        newBlackCanCastleQueenside = false;
      } else if (move.to == Position(7, 7)) {
        // h8 rook captured
        newBlackCanCastleKingside = false;
      }
    }

    // Track king promotions for Heir mode
    bool newWhiteHasPromotedKing = whiteHasPromotedKing;
    bool newBlackHasPromotedKing = blackHasPromotedKing;

    if (gameType == GameType.heir &&
        move.isPromotion &&
        move.promotionPiece == 'K') {
      if (move.piece.color == PieceColor.white) {
        newWhiteHasPromotedKing = true;
      } else {
        newBlackHasPromotedKing = true;
      }
    }

    // Create the new board state first
    final newBoard = copyWith(
      pieces: newPieces,
      currentPlayer: currentPlayer.opposite,
      moveHistory: [...moveHistory, move],
      enPassantTarget: newEnPassantTarget, // Clear or set en passant target
      whiteCanCastleKingside: newWhiteCanCastleKingside,
      whiteCanCastleQueenside: newWhiteCanCastleQueenside,
      blackCanCastleKingside: newBlackCanCastleKingside,
      blackCanCastleQueenside: newBlackCanCastleQueenside,
      whiteHasPromotedKing: newWhiteHasPromotedKing,
      blackHasPromotedKing: newBlackHasPromotedKing,
    );

    return newBoard;
  }
}
