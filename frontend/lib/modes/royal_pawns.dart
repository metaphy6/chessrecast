import '../board/utils/exporter.dart';
import 'game_mode.dart';
import 'modes_enum.dart';

/// ROYAL PAWNS MODE: Pawns move and capture like Kings
///
/// Rules:
/// - Pawns can move one square in ANY direction (like a King)
/// - Pawns can capture in ANY direction (like a King)
/// - Pawns CANNOT promote (they remain pawns even on the last rank)
/// - No two-square initial move
/// - No en passant in this mode
class RoyalPawns extends GameMode {
  @Deprecated(
    'Use the `modes.royalPawns` alias from modes_cache.dart instead of direct instantiation',
  )
  const RoyalPawns();
  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    final moves = <ChessMove>[];

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
        // Empty square - can move (no promotion in Royal Pawns mode)
        moves.add(
          ChessMove.simple(from: pawn.position, to: newPos, piece: pawn),
        );
      } else if (targetPiece.color != pawn.color) {
        // Enemy piece - can capture (but NOT the king, unless in Heir mode)
        if (targetPiece.type == PieceType.king &&
            board.gameType != ModesEnum.heir) {
          // Cannot capture the king in most modes - this should be an illegal move
          continue; // Skip this move
        }

        // No promotion in Royal Pawns mode, even when capturing on last rank
        moves.add(
          ChessMove.simple(
            from: pawn.position,
            to: newPos,
            piece: pawn,
            capturedPiece: targetPiece,
          ),
        );
      }
    }

    // Note: No two-square initial move in Royal Pawns mode
    // Pawns move like kings (one square at a time in any direction)
    // Note: No en passant in Royal Pawns mode since pawns can capture in all directions

    return moves;
  }
}
