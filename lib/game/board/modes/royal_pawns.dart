import '../board.dart';
import '../move.dart';
import '../position.dart';
import '../piece.dart';
import '../../enums/piece_color.dart';
import '../../enums/piece_type.dart';
import 'game_mode.dart';

/// ROYAL PAWNS MODE: Pawns move and capture like Kings
///
/// Rules:
/// - Pawns can move one square in ANY direction (like a King)
/// - Pawns can capture in ANY direction (like a King)
/// - Pawns can still do the two-square initial move from starting position
/// - Standard promotion rules apply
/// - En passant still works with standard diagonal captures
class RoyalPawnsMode extends GameMode {
  @override
  List<ChessMove>? getPawnMoves(ChessPiece pawn, ChessBoard board) {
    final moves = <ChessMove>[];

    print(
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
        print('✅ ROYAL PAWN can move to ${newPos.algebraic}');

        final lastRank = pawn.color == PieceColor.white ? 7 : 0;
        if (newPos.row == lastRank) {
          // Add promotion moves
          for (final promotionPiece in ['Q', 'R', 'B', 'N']) {
            print(
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
        print(
          '⚔️ ROYAL PAWN can capture: ${targetPiece.toString()} at ${newPos.algebraic}',
        );

        final lastRank = pawn.color == PieceColor.white ? 7 : 0;
        if (newPos.row == lastRank) {
          // Add promotion captures
          for (final promotionPiece in ['Q', 'R', 'B', 'N']) {
            print(
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
        print('🚫 ROYAL PAWN blocked by friendly piece at ${newPos.algebraic}');
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
          print(
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

    // Handle en passant
    if (board.enPassantTarget != null) {
      final enPassantRow = pawn.color == PieceColor.white ? 5 : 2;
      if (pawn.position.row == enPassantRow) {
        final colDiff = (board.enPassantTarget!.col - pawn.position.col).abs();
        if (colDiff == 1 &&
            board.enPassantTarget!.row ==
                pawn.position.row + (pawn.color == PieceColor.white ? 1 : -1)) {
          final capturedPawn = board.getPieceAt(
            Position(pawn.position.row, board.enPassantTarget!.col),
          );
          if (capturedPawn != null &&
              capturedPawn.type == PieceType.pawn &&
              capturedPawn.color != pawn.color) {
            print('🎯 En passant capture found!');
            moves.add(
              ChessMove.enPassant(
                from: pawn.position,
                to: board.enPassantTarget!,
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
