import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rule-mechanics tests for Kings' Battle.
///
/// Three events end Phase 1 (unlock all pieces):
///   1. King's Kill (king captures a pawn) — also grants the capturer one
///      bonus (additional) move. This is the ONLY way to earn a bonus.
///   2. A pawn promotion (with or without capture) — unlocks Phase 2 but
///      does NOT grant a bonus move.
///   3. Deadlock auto-unlock: 6 consecutive non-capturing king moves
///      across both colors (any pawn move or capture resets the
///      counter) — unlocks Phase 2, no bonus move.
/// Pawn captures (without promotion) and quiet pawn pushes do nothing.
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

    test(
      'pawn capturing an opponent pawn does NOT unlock and does NOT grant bonus',
      () {
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
        final afterCapture = orchestrator.executeMove(
          boardWithKnight,
          captureMove,
        );
        final knightMoves = orchestrator
            .getAllValidMoves(afterCapture)
            .where((m) => m.piece.type == PieceType.knight);
        expect(
          knightMoves,
          isEmpty,
          reason: 'Phase 1 must remain active after a pawn capture',
        );
      },
    );

    test('pawn promotion unlocks Phase 2 but does NOT grant a bonus move', () {
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

      // Phase 2 must now be unlocked. Give White a knight + reposition the
      // black king so it is White's turn again, then check the knight is
      // playable and the promoted queen is playable.
      final boardWithKnight = ChessBoard.fromFEN(
        '8/4P3/k7/8/8/8/8/N3K3 w - - 0 1',
        gameType: ModsEnum.kingsBattle,
      );
      final promoMove = _findMove(boardWithKnight, 'e7', 'e8', promotion: 'Q');
      var afterPromo = orchestrator.executeMove(boardWithKnight, promoMove);
      // Black plays any king move so it is White's turn again.
      final blackKingMove = _findMove(afterPromo, 'a6', 'b6');
      afterPromo = orchestrator.executeMove(afterPromo, blackKingMove);
      expect(afterPromo.currentPlayer, PieceColor.white);

      final knightMoves = orchestrator
          .getAllValidMoves(afterPromo)
          .where((m) => m.piece.type == PieceType.knight);
      expect(
        knightMoves,
        isNotEmpty,
        reason: 'Promotion must unlock all pieces (Phase 2 active)',
      );

      final queenMoves = orchestrator
          .getAllValidMoves(afterPromo)
          .where((m) => m.piece.type == PieceType.queen);
      expect(
        queenMoves,
        isNotEmpty,
        reason: 'Promoted queen must be playable once Phase 2 is unlocked',
      );
    });

    test(
      'deadlock auto-unlock: 6 consecutive non-capturing king moves unlock Phase 2',
      () {
        // Pawn fortress: every white pawn is blocked head-on by a black
        // pawn, so neither side has any legal pawn move. Add a white
        // knight on b1 and a black knight on b8 so we can verify they
        // are locked initially and unlock after the deadlock fires.
        // Kings start on e1/e8 with empty squares around them so they
        // can shuffle freely.
        final board = ChessBoard.fromFEN(
          '1n2k3/pppppppp/8/8/8/8/PPPPPPPP/1N2K3 w - - 0 1',
          gameType: ModsEnum.kingsBattle,
        );
        expect(board.currentPlayer, PieceColor.white);

        // Sanity: knight on b1 cannot move in Phase 1.
        final knightStartMoves = orchestrator
            .getAllValidMoves(board)
            .where((m) => m.piece.type == PieceType.knight);
        expect(
          knightStartMoves,
          isEmpty,
          reason: 'Phase 1 must lock the knight',
        );

        // Play a sequence of 6 quiet king moves alternating sides.
        // White: e1-d1, Black: e8-d8, White: d1-e1, Black: d8-e8,
        // White: e1-d1, Black: e8-d8.  None capture.
        final shuffles = <List<String>>[
          ['e1', 'd1'],
          ['e8', 'd8'],
          ['d1', 'e1'],
          ['d8', 'e8'],
          ['e1', 'd1'],
          ['e8', 'd8'],
        ];
        var current = board;
        for (final pair in shuffles) {
          final m = _findMove(current, pair[0], pair[1]);
          expect(m.piece.type, PieceType.king);
          expect(m.capturedPiece, isNull);
          current = orchestrator.executeMove(current, m);
        }

        // After the 6th non-capturing king move, Phase 2 must be
        // unlocked. The knight on b1 / b8 must now be playable
        // (depending on whose turn it is — White after Black's 6th).
        expect(current.currentPlayer, PieceColor.white);
        final knightMovesAfter = orchestrator
            .getAllValidMoves(current)
            .where((m) => m.piece.type == PieceType.knight);
        expect(
          knightMovesAfter,
          isNotEmpty,
          reason:
              'Deadlock auto-unlock must enable knight moves after the '
              '6th consecutive non-capturing king move',
        );
      },
    );

    test(
      'a pawn move resets the deadlock counter (no auto-unlock at 6 if a pawn moved in between)',
      () {
        // Same fortress as above but with one extra white pawn on a3
        // that CAN push to a4 (clear lane), and one extra black pawn on
        // h6 that can push to h5. We mix a pawn move into a sequence of
        // king moves to ensure the counter resets and the knight stays
        // locked.
        final board = ChessBoard.fromFEN(
          '1n2k3/pppppppp/7p/8/8/P7/1PPPPPPP/1N2K3 w - - 0 1',
          gameType: ModsEnum.kingsBattle,
        );

        var current = board;
        // 5 king shuffles (counter -> 5), then a pawn push (reset),
        // then 5 more king shuffles (counter -> 5, not 6).
        final firstFive = <List<String>>[
          ['e1', 'd1'],
          ['e8', 'd8'],
          ['d1', 'e1'],
          ['d8', 'e8'],
          ['e1', 'd1'],
        ];
        for (final p in firstFive) {
          final m = _findMove(current, p[0], p[1]);
          current = orchestrator.executeMove(current, m);
        }

        // Black pushes h6-h5 (pawn move resets counter).
        final pawnPush = _findMove(current, 'h6', 'h5');
        expect(pawnPush.piece.type, PieceType.pawn);
        current = orchestrator.executeMove(current, pawnPush);

        // 5 more king shuffles.
        final lastFive = <List<String>>[
          ['d1', 'e1'],
          ['e8', 'd8'],
          ['e1', 'd1'],
          ['d8', 'e8'],
          ['d1', 'e1'],
        ];
        for (final p in lastFive) {
          final m = _findMove(current, p[0], p[1]);
          current = orchestrator.executeMove(current, m);
        }

        // Counter never reached 6 in a row, so knight must still be locked.
        final knightMoves = orchestrator
            .getAllValidMoves(current)
            .where((m) => m.piece.type == PieceType.knight);
        expect(
          knightMoves,
          isEmpty,
          reason:
              'A pawn move must reset the deadlock counter; the knight '
              'must still be locked',
        );
      },
    );
  });
}
