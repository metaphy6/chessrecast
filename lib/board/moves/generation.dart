import '../enums/piece_color.dart';
import '../enums/piece_type.dart';
import '../models/position.dart';
import '../models/piece.dart';
import '../models/move.dart';
import '../models/board.dart';
import '../queries.dart';
import 'validation.dart';

/// Extension for move generation operations
extension MoveGeneration on ChessBoard {
  /// Gets all valid moves for a piece at the specified position
  List<ChessMove> getValidMovesFor(Position position) {
    final piece = getPieceAt(position);
    if (piece == null || piece.color != currentPlayer) {
      return [];
    }
    final potentialMoves = _getPotentialMoves(piece);

    // Filter out moves that would put own king in check
    final safeMoves = potentialMoves.where((move) {
      final boardAfterMove = makeMoveForValidation(move);
      final kingInCheck = boardAfterMove.isKingInCheck(currentPlayer);
      if (kingInCheck) {
      } else {
      }
      return !kingInCheck;
    }).toList();

    return safeMoves;
  }

  /// Gets all potential moves for a piece (without checking for king safety)
  List<ChessMove> _getPotentialMoves(ChessPiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        return _getPawnMoves(piece);
      case PieceType.rook:
        return _getRookMoves(piece);
      case PieceType.knight:
        return _getKnightMoves(piece);
      case PieceType.bishop:
        return _getBishopMoves(piece);
      case PieceType.queen:
        return _getQueenMoves(piece);
      case PieceType.king:
        return _getKingMoves(piece);
    }
  }

  List<ChessMove> _getPawnMoves(ChessPiece pawn) {
    final moves = <ChessMove>[];
    final direction = pawn.color == PieceColor.white ? 1 : -1;
    final startRow = pawn.color == PieceColor.white ? 1 : 6;

    // Debug en passant target - always print

    if (enPassantTarget != null) {
    }

    // Forward move
    final oneStep = pawn.position.offset(direction, 0);
    if (oneStep.isValid && getPieceAt(oneStep) == null) {
      // Check for promotion
      final lastRank = pawn.color == PieceColor.white ? 7 : 0;
      if (oneStep.row == lastRank) {
        // Add promotion moves
        for (final promotionPiece in getPromotionPieces(
          pawn.color,
          promotionPosition: oneStep,
        )) {
          moves.add(
            ChessMove.promotion(
              from: pawn.position,
              to: oneStep,
              piece: pawn,
              promotionPiece: promotionPiece,
            ),
          );
        }
      } else {
        // Regular forward move
        moves.add(
          ChessMove.simple(from: pawn.position, to: oneStep, piece: pawn),
        );
      }

      // Two-step move from starting position
      if (pawn.position.row == startRow) {
        final twoStep = pawn.position.offset(direction * 2, 0);
        if (twoStep.isValid && getPieceAt(twoStep) == null) {
          moves.add(
            ChessMove.simple(from: pawn.position, to: twoStep, piece: pawn),
          );
        }
      }
    }

    // Diagonal captures
    for (final colOffset in [-1, 1]) {
      final capturePos = pawn.position.offset(direction, colOffset);
      if (capturePos.isValid) {
        final targetPiece = getPieceAt(capturePos);
        if (targetPiece != null && targetPiece.color != pawn.color) {
          // Check for promotion when capturing
          final lastRank = pawn.color == PieceColor.white ? 7 : 0;
          if (capturePos.row == lastRank) {
            // Add promotion captures
            for (final promotionPiece in getPromotionPieces(
              pawn.color,
              promotionPosition: capturePos,
            )) {
              moves.add(
                ChessMove.promotion(
                  from: pawn.position,
                  to: capturePos,
                  piece: pawn,
                  capturedPiece: targetPiece,
                  promotionPiece: promotionPiece,
                ),
              );
            }
          } else {
            // Regular capture
            moves.add(
              ChessMove.simple(
                from: pawn.position,
                to: capturePos,
                piece: pawn,
                capturedPiece: targetPiece,
              ),
            );
          }
        }

        // En passant
        if (capturePos == enPassantTarget) {
          // The captured pawn is on the same row as the attacking pawn
          final capturedPawn = getPieceAt(
            Position(pawn.position.row, capturePos.col),
          );
          if (capturedPawn != null && capturedPawn.type == PieceType.pawn) {
            moves.add(
              ChessMove.enPassant(
                from: pawn.position,
                to: capturePos,
                piece: pawn,
                capturedPiece: capturedPawn,
              ),
            );
          }
        }
      }
    }

    return moves;
  }

  /// Gets available promotion pieces based on game mode and player state
  List<String> getPromotionPieces(
    PieceColor color, {
    Position? promotionPosition,
  }) {
    return ['Q', 'R', 'B', 'N']; // Standard promotion pieces
  }

  List<ChessMove> _getRookMoves(ChessPiece rook) {
    final moves = <ChessMove>[];
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1], // up, down, left, right
    ];

    for (final direction in directions) {
      for (int i = 1; i < 8; i++) {
        final newPos = rook.position.offset(direction[0] * i, direction[1] * i);
        if (!newPos.isValid) break;

        final targetPiece = getPieceAt(newPos);
        if (targetPiece == null) {
          moves.add(
            ChessMove.simple(from: rook.position, to: newPos, piece: rook),
          );
        } else {
          if (targetPiece.color != rook.color) {
            moves.add(
              ChessMove.simple(
                from: rook.position,
                to: newPos,
                piece: rook,
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

  List<ChessMove> _getKnightMoves(ChessPiece knight) {
    final moves = <ChessMove>[];
    final knightMoves = [
      [-2, -1],
      [-2, 1],
      [-1, -2],
      [-1, 2],
      [1, -2],
      [1, 2],
      [2, -1],
      [2, 1],
    ];

    for (final move in knightMoves) {
      final newPos = knight.position.offset(move[0], move[1]);
      if (!newPos.isValid) continue;

      final targetPiece = getPieceAt(newPos);
      if (targetPiece == null || targetPiece.color != knight.color) {
        moves.add(
          ChessMove.simple(
            from: knight.position,
            to: newPos,
            piece: knight,
            capturedPiece: targetPiece,
          ),
        );
      }
    }

    return moves;
  }

  List<ChessMove> _getBishopMoves(ChessPiece bishop) {
    final moves = <ChessMove>[];
    final directions = [
      [-1, -1],
      [-1, 1],
      [1, -1],
      [1, 1], // diagonals
    ];

    for (final direction in directions) {
      for (int i = 1; i < 8; i++) {
        final newPos = bishop.position.offset(
          direction[0] * i,
          direction[1] * i,
        );
        if (!newPos.isValid) break;

        final targetPiece = getPieceAt(newPos);
        if (targetPiece == null) {
          moves.add(
            ChessMove.simple(from: bishop.position, to: newPos, piece: bishop),
          );
        } else {
          if (targetPiece.color != bishop.color) {
            moves.add(
              ChessMove.simple(
                from: bishop.position,
                to: newPos,
                piece: bishop,
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

  List<ChessMove> _getQueenMoves(ChessPiece queen) {
    return [..._getRookMoves(queen), ..._getBishopMoves(queen)];
  }

  List<ChessMove> _getKingMoves(ChessPiece king) {
    final moves = <ChessMove>[];
    final directions = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];

    for (final direction in directions) {
      final newPos = king.position.offset(direction[0], direction[1]);
      if (!newPos.isValid) continue;

      final targetPiece = getPieceAt(newPos);
      if (targetPiece == null || targetPiece.color != king.color) {
        moves.add(
          ChessMove.simple(
            from: king.position,
            to: newPos,
            piece: king,
            capturedPiece: targetPiece,
          ),
        );
      }
    }

    // Add castling moves if conditions are met
    if (king.color == PieceColor.white) {
      // White kingside castling (O-O)
      if (whiteCanCastleKingside && canCastleKingside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(0, 6), // g1
          piece: king,
        );
        moves.add(castleMove);
      }

      // White queenside castling (O-O-O)
      if (whiteCanCastleQueenside && canCastleQueenside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(0, 2), // c1
          piece: king,
        );
        moves.add(castleMove);
      }
    } else {
      // Black kingside castling (O-O)
      if (blackCanCastleKingside && canCastleKingside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(7, 6), // g8
          piece: king,
        );
        moves.add(castleMove);
      }

      // Black queenside castling (O-O-O)
      if (blackCanCastleQueenside && canCastleQueenside(king.color)) {
        final castleMove = ChessMove.castling(
          from: king.position,
          to: Position(7, 2), // c8
          piece: king,
        );
        moves.add(castleMove);
      }
    }

    return moves;
  }
}
