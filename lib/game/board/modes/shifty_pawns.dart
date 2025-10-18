import '../board.dart';
import '../move.dart';
import '../position.dart';
import '../piece.dart';
import '../../enums/piece_color.dart';
import '../../enums/piece_type.dart';
import 'game_mode.dart';

/// SHIFTY PAWNS MODE: Pawns move like Kings but capture like regular pawns
///
/// Rules:
/// - Pawns can move one square in ANY direction (like a King)
/// - Pawns can ONLY capture diagonally forward (like regular pawns)
/// - Pawns can still do the two-square initial move from starting position
/// - Standard promotion rules apply
/// - En passant still works with standard diagonal captures
class ShiftyPawnsMode extends GameMode {
  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    final moves = <ChessMove>[];
    final direction = pawn.color == PieceColor.white ? 1 : -1;

    print(
      '🔄 SHIFTY PAWN: ${pawn.position.algebraic} can move like a king but capture like a regular pawn!',
    );

    // King-like movement (one square in any direction) for MOVEMENT ONLY
    final kingMoves = [
      [-1, -1],
      [-1, 0],
      [-1, 1],
      [0, -1],
      [0, 1],
      [1, -1],
      [1, 0],
      [1, 1],
    ];

    for (final moveOffset in kingMoves) {
      final newPos = pawn.position.offset(moveOffset[0], moveOffset[1]);
      if (!newPos.isValid) continue;

      final targetPiece = board.getPieceAt(newPos);

      // Can only move to empty squares
      if (targetPiece == null) {
        print('✅ SHIFTY PAWN can move to ${newPos.algebraic}');

        final lastRank = pawn.color == PieceColor.white ? 7 : 0;
        if (newPos.row == lastRank) {
          // Add promotion moves
          for (final promotionPiece in ['Q', 'R', 'B', 'N']) {
            print(
              '👑 SHIFTY PAWN promotion move: ${pawn.position.algebraic} → ${newPos.algebraic} = $promotionPiece',
            );
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
    if (pawn.position.row == startRow) {
      final twoSquarePos = pawn.position.offset(direction * 2, 0);
      if (twoSquarePos.isValid && board.getPieceAt(twoSquarePos) == null) {
        final oneSquarePos = pawn.position.offset(direction, 0);
        if (board.getPieceAt(oneSquarePos) == null) {
          print(
            '🚀 SHIFTY PAWN can move 2 squares forward from starting position',
          );
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

    // Regular pawn captures (diagonal forward only)
    for (final colOffset in [-1, 1]) {
      final capturePos = pawn.position.offset(direction, colOffset);
      if (capturePos.isValid) {
        final targetPiece = board.getPieceAt(capturePos);
        if (targetPiece != null && targetPiece.color != pawn.color) {
          print(
            '⚔️ SHIFTY PAWN can capture diagonally: ${targetPiece.toString()} at ${capturePos.algebraic}',
          );

          final lastRank = pawn.color == PieceColor.white ? 7 : 0;
          if (capturePos.row == lastRank) {
            // Add promotion captures
            for (final promotionPiece in ['Q', 'R', 'B', 'N']) {
              print(
                '👑 SHIFTY PAWN promotion capture: ${pawn.position.algebraic} → ${capturePos.algebraic} = $promotionPiece',
              );
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

        // En passant
        if (capturePos == board.enPassantTarget) {
          final capturedPawn = board.getPieceAt(
            Position(pawn.position.row, capturePos.col),
          );
          if (capturedPawn != null && capturedPawn.type == PieceType.pawn) {
            print('🎯 En passant capture found!');
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
}
