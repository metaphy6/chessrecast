import 'package:chessrecast/debug.dart';
import '../board/exporter.dart';
import 'game_mode.dart';
import 'modes_enum.dart';

/// ROYAL PAWNS MODE: Pawns move and capture like Kings
///
/// Rules:
/// - Pawns can move one square in ANY direction (like a King)
/// - Pawns can capture in ANY direction (like a King)
/// - Standard promotion rules apply when reaching the last rank
/// - No two-square initial move
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
        // Enemy piece - can capture (but NOT the king, unless in Heir mode)
        if (targetPiece.type == PieceType.king &&
            board.gameType != ModesEnum.heir) {
          // Cannot capture the king in most modes - this should be an illegal move
          printDebug(
            '👑 ROYAL PAWN cannot capture king at ${newPos.algebraic} - illegal move (except in Heir mode)',
          );
          continue; // Skip this move
        }

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

    // Note: No two-square initial move in Royal Pawns mode
    // Pawns move like kings (one square at a time in any direction)
    // Note: No en passant in Royal Pawns mode since pawns can capture in all directions

    return moves;
  }
}
