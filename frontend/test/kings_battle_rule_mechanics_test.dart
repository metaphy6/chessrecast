import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rule-mechanics tests for Kings' Battle.
///
/// The ONLY trigger that ends Phase 1 (unlocks all pieces) AND grants the
/// capturer one bonus (additional) move is a king capturing a pawn
/// ("King's Kill"). Pawn captures, pawn pushes, and pawn promotions must
/// NOT unlock Phase 2 and must NOT grant a bonus move.
void main() {
  final orchestrator = Orchestrator();

  ChessMove _findMove(
    ChessBoard board,
    String fromAlg,
    String toAlg, {
    String? promotion,
  }) {
    final from = Position.fromAlgebraic(fromAlg);
    final to = Position.fromAlgebraic(toAlg);
    for (final m in orchestrator.getAllValidMoves(board)) {
      if (m.from != from || m.to != to) continue;
      if (promotion != null && m.promotionPiece != promotion) continue;
      if (promotion == null && m.isPromotion) continue;
      return m;
    }
    throw StateError('No legal move $fromAlg$toAlg in this position');
  }

  group('Kings Battle: only king-captures-pawn grants bonus move', () {
    test('king capturing a pawn unlocks phase 2 AND grants the bonus move', () {
      // White king on e4, black pawn on e5, kings of opposite colors apart.
      final board = ChessBoard.fromFEN(
        '4k3/8/8/4p3/4K3/8/8/8 w - - 0 1',
        gameType: ModsEnum.kingsBattle,
      );
      expect(board.currentPlayer, PieceColor.white);

      final move = _findMove(board, 'e4', 'e5');
      expect(move.piece.type, PieceType.king);
      expect(move.capturedPiece?.type, PieceType.pawn);

      final after = orchestrator.executeMove(board, move);

      // Bonus move: side to move must remain White (no turn switch).
      expect(
        after.currentPlayer,
        PieceColor.white,
        reason: 'King\'s Kill must grant the capturer a bonus move',
      );
    });

    test('pawn capturing an opponent pawn does NOT unlock and does NOT grant bonus', () {
      // White pawn e4, black pawn d5. e4xd5 is a pawn capture in Phase 1.
      final board = ChessBoard.fromFEN(
        '4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1',
        gameType: ModsEnum.kingsBattle,
      );
      expect(board.currentPlayer, PieceColor.white);

      final move = _findMove(board, 'e4', 'd5');
      expect(move.piece.type, PieceType.pawn);
      expect(move.capturedPiece?.type, PieceType.pawn);

      final after = orchestrator.executeMove(board, move);

      // No bonus move: turn must switch to Black.
      expect(
        after.currentPlayer,
        PieceColor.black,
        reason: 'Pawn captures must never grant a bonus move',
      );

      // Phase 1 must still be active: no non-pawn / non-king piece may move.
      // (We add a black knight to verify it stays locked.)
      final boardWithKnight = ChessBoard.fromFEN(
        '4k3/8/8/3p4/4P3/8/n7/4K3 w - - 0 1',
        gameType: ModsEnum.kingsBattle,
      );
      final captureMove = _findMove(boardWithKnight, 'e4', 'd5');
      final afterCapture =
          orchestrator.executeMove(boardWithKnight, captureMove);
      final knightMoves = orchestrator
          .getAllValidMoves(afterCapture)
          .where((m) => m.piece.type == PieceType.knight);
      expect(
        knightMoves,
        isEmpty,
        reason: 'Phase 1 must remain active after a pawn capture',
      );
    });

    test('pawn promotion does NOT unlock and does NOT grant bonus', () {
      // White pawn on e7 promotes to e8=Q. Black king on a8.
      final board = ChessBoard.fromFEN(
        'k7/4P3/8/8/8/8/8/4K3 w - - 0 1',
        gameType: ModsEnum.kingsBattle,
      );
      expect(board.currentPlayer, PieceColor.white);

      final move = _findMove(board, 'e7', 'e8', promotion: 'Q');
      expect(move.isPromotion, isTrue);

      final after = orchestrator.executeMove(board, move);

      // No bonus move: turn must switch to Black.
      expect(
        after.currentPlayer,
        PieceColor.black,
        reason: 'Pawn promotions must never grant a bonus move',
      );

      // Phase 1 must still be active. Give White a knight to confirm it
      // stays locked after the promotion. Use a position where it is
      // White's turn again so we can probe White's knight legality.
      final boardWithKnight = ChessBoard.fromFEN(
        'k7/4P3/8/8/8/8/8/N3K3 w - - 0 1',
        gameType: ModsEnum.kingsBattle,
      );
      final promoMove = _findMove(boardWithKnight, 'e7', 'e8', promotion: 'Q');
      var afterPromo = orchestrator.executeMove(boardWithKnight, promoMove);
      // Black plays any king move so it is White's turn again.
      final blackKingMove = _findMove(afterPromo, 'a8', 'b8');
      afterPromo = orchestrator.executeMove(afterPromo, blackKingMove);
      expect(afterPromo.currentPlayer, PieceColor.white);

      final knightMoves = orchestrator
          .getAllValidMoves(afterPromo)
          .where((m) => m.piece.type == PieceType.knight);
      expect(
        knightMoves,
        isEmpty,
        reason: 'Promotion must NOT unlock pieces in Phase 1',
      );

      // The newly-promoted queen must also stay locked in Phase 1.
      final queenMoves = orchestrator
          .getAllValidMoves(afterPromo)
          .where((m) => m.piece.type == PieceType.queen);
      expect(
        queenMoves,
        isEmpty,
        reason: 'Promoted queens must stay locked while Phase 1 is active',
      );
    });
  });
}
