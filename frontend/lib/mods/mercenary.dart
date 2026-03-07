import '../board/utils/exporter.dart';
import 'game_mod.dart';
import 'mods_enum.dart';

/// Mercenary Mod: Pawns move and capture like Kings
///
/// Rules:
/// - Pawns can move one square in ANY direction (like a King)
/// - Pawns can capture in ANY direction (like a King)
/// - Pawns CANNOT promote (they remain pawns even on the last rank)
/// - No two-square initial move
/// - No en passant in this mode
/// - Pawn moves count as regular moves (increment fifty-move counter)
///
/// Draw Conditions:
/// - Standard 100 half-move rule (50 full moves)
/// - Insufficient material: K vs K, or K+N vs K+N (no pawns)
/// - With pawns on board, checkmate is possible (pawns assist like kings)
class Mercenary extends GameMod {
  @Deprecated(
    'Use the `mods.mercenary` alias from mods_cache.dart instead of direct instantiation',
  )
  const Mercenary();
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
        // Empty square - can move (no promotion in Mercenary Mod)
        moves.add(
          ChessMove.simple(from: pawn.position, to: newPos, piece: pawn),
        );
      } else if (targetPiece.color != pawn.color) {
        // Enemy piece - can capture (but NOT the king, unless in Heir Mod)
        if (targetPiece.type == PieceType.king &&
            board.gameType != ModsEnum.heir) {
          // Cannot capture the king in most mods - this should be an illegal move
          continue; // Skip this move
        }

        // No promotion in Mercenary Mod, even when capturing on last rank
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

    // Note: No two-square initial move in Mercenary Mod
    // Pawns move like kings (one square at a time in any direction)
    // Note: No en passant in Mercenary Mod since pawns can capture in all directions

    return moves;
  }
}
