import 'position.dart';
import 'move.dart';
import '../piece.dart';
import '../board.dart';
import '../items/piece_type.dart';
import '../items/piece_color.dart';

/// Helper utilities for move generation and execution to reduce duplication
extension MoveHelpers on ChessBoard {
  /// Generates sliding moves for pieces like Rook, Bishop, Queen
  List<ChessMove> generateSlidingMoves(
    ChessPiece piece,
    List<List<int>> directions,
  ) {
    final moves = <ChessMove>[];

    for (final direction in directions) {
      for (int i = 1; i < 8; i++) {
        final newPos = piece.position.offset(
          direction[0] * i,
          direction[1] * i,
        );
        if (!newPos.isValid) break;

        final targetPiece = getPieceAt(newPos);
        if (targetPiece == null) {
          moves.add(
            ChessMove.simple(from: piece.position, to: newPos, piece: piece),
          );
        } else {
          if (targetPiece.color != piece.color) {
            moves.add(
              ChessMove.simple(
                from: piece.position,
                to: newPos,
                piece: piece,
                capturedPiece: targetPiece,
              ),
            );
          }
          break;
        }
      }
    }

    return moves;
  }

  /// Computes new castling rights after a move given the current flags, returns a
  /// map with updated rights.
  Map<String, bool> computeNewCastlingRights(
    ChessMove move,
    bool whiteCanCastleKingside,
    bool whiteCanCastleQueenside,
    bool blackCanCastleKingside,
    bool blackCanCastleQueenside,
  ) {
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

    return {
      'whiteCanCastleKingside': newWhiteCanCastleKingside,
      'whiteCanCastleQueenside': newWhiteCanCastleQueenside,
      'blackCanCastleKingside': newBlackCanCastleKingside,
      'blackCanCastleQueenside': newBlackCanCastleQueenside,
    };
  }

  /// Generates single-step moves (knight, king) based on offsets
  List<ChessMove> generateStepMoves(ChessPiece piece, List<List<int>> offsets) {
    final moves = <ChessMove>[];
    for (final move in offsets) {
      final newPos = piece.position.offset(move[0], move[1]);
      if (!newPos.isValid) continue;

      final targetPiece = getPieceAt(newPos);
      if (targetPiece == null || targetPiece.color != piece.color) {
        moves.add(
          ChessMove.simple(
            from: piece.position,
            to: newPos,
            piece: piece,
            capturedPiece: targetPiece,
          ),
        );
      }
    }
    return moves;
  }

  /// Moves the rook for a castling move inside the provided "newPieces" list.
  /// `kingFrom` and `kingTo` indicate the king's original and destination positions
  /// so the helper can determine kingside vs queenside castling.
  void performCastlingRookMove(
    List<ChessPiece> newPieces,
    Position kingFrom,
    Position kingTo,
  ) {
    final kingRow = kingFrom.row;
    final isKingside = kingTo.col == 6; // g-file

    if (isKingside) {
      // move rook from h-file to f-file
      final rookPos = Position(kingRow, 7);
      // Remove rook from its original square in newPieces
      newPieces.removeWhere((piece) => piece.position == rookPos);
      // If there was a rook, move it to f-file (col 5)
      // Find rook from the original board - it may not have been removed earlier
      final rook = getPieceAt(rookPos);
      if (rook != null) {
        newPieces.add(rook.movedTo(Position(kingRow, 5))); // f-file
      }
    } else {
      // queenside: move rook from a-file to d-file
      final rookPos = Position(kingRow, 0);
      newPieces.removeWhere((piece) => piece.position == rookPos);
      final rook = getPieceAt(rookPos);
      if (rook != null) {
        newPieces.add(rook.movedTo(Position(kingRow, 3))); // d-file
      }
    }
  }

  /// Compute en passant target for a pawn double step move; returns null if none
  Position? computeEnPassantTargetForMove(ChessMove move) {
    if (move.piece.type != PieceType.pawn) return null;
    final rowDiff = (move.to.row - move.from.row).abs();
    if (rowDiff == 2) {
      final targetRow = (move.from.row + move.to.row) ~/ 2;
      return Position(targetRow, move.from.col);
    }
    return null;
  }

  /// Given a destination 'to' and an optional captured piece, create either
  /// a simple move or a set of promotion moves if the piece is a pawn that
  /// reaches the last rank.
  List<ChessMove> createMovesWithPromotionCheck(
    ChessPiece piece,
    Position to, {
    ChessPiece? capturedPiece,
    List<String>? promotionOptions,
  }) {
    final moves = <ChessMove>[];
    // Only pawns promote
    if (piece.type == PieceType.pawn) {
      final lastRank = piece.color == PieceColor.white ? 7 : 0;
      if (to.row == lastRank) {
        final options = promotionOptions;
        if (options != null) {
          for (final promotionPiece in options) {
            moves.add(
              ChessMove.promotion(
                from: piece.position,
                to: to,
                piece: piece,
                capturedPiece: capturedPiece,
                promotionPiece: promotionPiece,
              ),
            );
          }
        }
        return moves;
      }
    }

    // Not a promotion, add simple or capture move
    moves.add(
      ChessMove.simple(
        from: piece.position,
        to: to,
        piece: piece,
        capturedPiece: capturedPiece,
      ),
    );
    return moves;
  }
}
