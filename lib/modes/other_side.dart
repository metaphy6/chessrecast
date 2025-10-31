import 'package:chessrecast/debug.dart';
import '../board/exporter.dart';
import 'game_mode.dart';

/// OTHER SIDE MODE: Race your rook to the opponent's back rank!
///
/// WIN CONDITIONS:
/// - Your rook reaches the opponent's back rank (rank 8 for white, rank 1 for black)
/// - You checkmate the opponent's king
/// - You capture an opponent's rook (instant win)
///
/// SPECIAL RULES:
/// 1. Pawns can move backward and capture diagonally (forward or backward)
/// 2. Losing a rook results in immediate game loss
/// 3. Rooks can only capture opponent rooks (cannot capture other pieces)
class OtherSide extends GameMode {
  @override
  ChessBoard? handleSpecialMove(ChessBoard board, ChessMove move) {
    // Check if a rook was captured - instant loss for the player who lost it
    if (move.capturedPiece != null &&
        move.capturedPiece!.type == PieceType.rook) {
      printDebug('🏰 OTHER SIDE: Rook captured! Opponent wins!');
      // Opponent wins by checkmate
      final newBoard = board.makeMove(move);
      return newBoard.copyWith(gameStatus: GameStatus.checkmate);
    }

    // Check if a rook reached the opponent's back rank
    if (move.piece.type == PieceType.rook) {
      final movingColor = move.piece.color;
      final targetRank = movingColor == PieceColor.white ? 7 : 0; // Rank 8 or 1

      if (move.to.row == targetRank) {
        printDebug(
          '🏰 OTHER SIDE: Rook reached the back rank! ${movingColor.name} wins!',
        );
        final newBoard = board.makeMove(move);
        return newBoard.copyWith(gameStatus: GameStatus.checkmate);
      }
    }

    return null; // No special handling, continue with normal move
  }

  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    final moves = <ChessMove>[];

    printDebug(
      '🔄 OTHER SIDE PAWN: ${pawn.position.algebraic} can move forward/backward and capture diagonally in both directions',
    );

    // Pawns can move one square forward OR backward
    for (final direction in [1, -1]) {
      final newPos = pawn.position.offset(direction, 0);
      if (!newPos.isValid) continue;

      final targetPiece = board.getPieceAt(newPos);
      if (targetPiece == null) {
        // Check for promotion
        final lastRank = pawn.color == PieceColor.white ? 7 : 0;
        if (newPos.row == lastRank) {
          // Add promotion moves
          for (final promotionPiece in board.getPromotionPieces(
            pawn.color,
            promotionPosition: newPos,
          )) {
            moves.add(
              ChessMove.promotion(
                from: pawn.position,
                to: newPos,
                piece: pawn,
                promotionPiece: promotionPiece,
              ),
            );
          }
        } else {
          moves.add(
            ChessMove.simple(from: pawn.position, to: newPos, piece: pawn),
          );
        }
      }
    }

    // Two-square forward move from starting position
    final startRow = pawn.color == PieceColor.white ? 1 : 6;
    final forwardDirection = pawn.color == PieceColor.white ? 1 : -1;

    if (pawn.position.row == startRow) {
      final twoSquarePos = pawn.position.offset(forwardDirection * 2, 0);
      if (twoSquarePos.isValid && board.getPieceAt(twoSquarePos) == null) {
        final oneSquarePos = pawn.position.offset(forwardDirection, 0);
        if (board.getPieceAt(oneSquarePos) == null) {
          moves.add(
            ChessMove.simple(
              from: pawn.position,
              to: twoSquarePos,
              piece: pawn,
            ),
          );
        }
      }
    }

    // Diagonal captures (both forward and backward)
    for (final rowOffset in [1, -1]) {
      for (final colOffset in [-1, 1]) {
        final capturePos = pawn.position.offset(rowOffset, colOffset);
        if (!capturePos.isValid) continue;

        final targetPiece = board.getPieceAt(capturePos);
        if (targetPiece != null && targetPiece.color != pawn.color) {
          // Check for promotion
          final lastRank = pawn.color == PieceColor.white ? 7 : 0;
          if (capturePos.row == lastRank) {
            // Add promotion captures
            for (final promotionPiece in board.getPromotionPieces(
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

        // En passant (only forward direction)
        if (rowOffset == forwardDirection &&
            capturePos == board.enPassantTarget) {
          final capturedPawn = board.getPieceAt(
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

  @override
  List<ChessMove> filterMoves(
    List<ChessMove> moves,
    ChessPiece piece,
    ChessBoard board,
  ) {
    // Only filter rook moves - rooks can only capture opponent rooks
    if (piece.type != PieceType.rook) {
      return moves; // Other pieces use standard rules
    }

    printDebug(
      '🏰 OTHER SIDE: Filtering rook moves - can only capture opponent rooks',
    );

    // Filter out moves where rook captures non-rook pieces
    return moves.where((move) {
      if (move.capturedPiece == null) {
        // Can move to empty squares
        return true;
      }

      // Can only capture opponent rooks
      final canCapture =
          move.capturedPiece!.type == PieceType.rook &&
          move.capturedPiece!.color != piece.color;

      if (!canCapture) {
        printDebug(
          '🏰 OTHER SIDE: Blocking rook capture of ${move.capturedPiece!.type.name} at ${move.to.algebraic}',
        );
      }

      return canCapture;
    }).toList();
  }
}
