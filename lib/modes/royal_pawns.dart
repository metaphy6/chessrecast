import 'package:chessrecast/debug.dart';
import '../board/exporter.dart';
import 'game_mode.dart';

/// ROYAL PAWNS MODE: Pawns move and capture like Kings
///
/// Rules:
/// - Pawns can move one square in ANY direction (like a King)
/// - Pawns can capture in ANY direction (like a King)
/// - Pawns can still do the two-square initial move forward from starting position
/// - Standard promotion rules apply when reaching the last rank
/// - No en passant in this mode
class RoyalPawns extends GameMode {
  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    final moves = <ChessMove>[];

    printDebug(
      '👑 ROYAL PAWN: ${pawn.position.algebraic} can move and capture like a king!',
    );

    // King-like moves (one square in any direction)
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

      if (targetPiece == null) {
        // Empty square - can move
        printDebug('✅ ROYAL PAWN can move to ${newPos.algebraic}');

        final lastRank = pawn.color == PieceColor.white ? 7 : 0;
        if (newPos.row == lastRank) {
          // Add promotion moves
          for (final promotionPiece in ['Q', 'R', 'B', 'N']) {
            printDebug(
              '👑 ROYAL PAWN promotion move: ${pawn.position.algebraic} → ${newPos.algebraic} = $promotionPiece',
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
      } else if (targetPiece.color != pawn.color) {
        // Enemy piece - can capture
        printDebug(
          '⚔️ ROYAL PAWN can capture: ${targetPiece.toString()} at ${newPos.algebraic}',
        );

        final lastRank = pawn.color == PieceColor.white ? 7 : 0;
        if (newPos.row == lastRank) {
          // Add promotion captures
          for (final promotionPiece in ['Q', 'R', 'B', 'N']) {
            printDebug(
              '👑 ROYAL PAWN promotion capture: ${pawn.position.algebraic} → ${newPos.algebraic} = $promotionPiece',
            );
            moves.add(
              ChessMove.promotion(
                from: pawn.position,
                to: newPos,
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
              to: newPos,
              piece: pawn,
              capturedPiece: targetPiece,
            ),
          );
        }
      } else {
        printDebug(
          '🚫 ROYAL PAWN blocked by friendly piece at ${newPos.algebraic}',
        );
      }
    }

    // Two-square forward move from starting position
    final startRow = pawn.color == PieceColor.white ? 1 : 6;
    final direction = pawn.color == PieceColor.white ? 1 : -1;

    if (pawn.position.row == startRow) {
      final twoSquarePos = pawn.position.offset(direction * 2, 0);
      if (twoSquarePos.isValid && board.getPieceAt(twoSquarePos) == null) {
        final oneSquarePos = pawn.position.offset(direction, 0);
        if (board.getPieceAt(oneSquarePos) == null) {
          printDebug(
            '🚀 ROYAL PAWN can move 2 squares forward from starting position',
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

    // Note: No en passant in Royal Pawns mode since pawns can capture in all directions

    return moves;
  }
}
