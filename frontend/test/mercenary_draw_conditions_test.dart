import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final orchestrator = Orchestrator();

  group('Mercenary draw conditions', () {
    test('King + pawn vs king can be a legal checkmate', () {
      // Black to move in a corner net.
      // Black king a8 is checked by white pawn b7 and has no legal escape.
      final board = ChessBoard.fromFEN(
        'k7/1P6/2K5/8/8/8/8/8 b - - 0 1',
        gameType: ModsEnum.mercenary,
      );

      final updated = orchestrator.updateGameStatus(board);

      expect(updated.isKingInCheck(PieceColor.black), isTrue);
      expect(orchestrator.getAllValidMoves(updated), isEmpty);
      expect(updated.gameStatus, equals(GameStatus.checkmate));
    });

    test('King + pawn vs king is not auto-drawn at 49 half-moves', () {
      final board = ChessBoard.fromFEN(
        '7k/8/8/8/3P4/2K5/8/8 b - - 49 1',
        gameType: ModsEnum.mercenary,
      );

      final updated = orchestrator.updateGameStatus(board);

      expect(updated.gameStatus, equals(GameStatus.ongoing));
    });

    test('King + pawn vs king draws at 50 half-moves', () {
      final board = ChessBoard.fromFEN(
        '7k/8/8/8/3P4/2K5/8/8 b - - 50 1',
        gameType: ModsEnum.mercenary,
      );

      final updated = orchestrator.updateGameStatus(board);

      expect(updated.gameStatus, equals(GameStatus.draw));
    });

    test('King + pawn vs king can claim fifty-move draw at 50 half-moves', () {
      final board = ChessBoard.fromFEN(
        '7k/8/8/8/3P4/2K5/8/8 b - - 50 1',
        gameType: ModsEnum.mercenary,
      );

      expect(board.canClaimFiftyMoveRule(), isTrue);
    });

    test('King vs king remains draw by insufficient material', () {
      final board = ChessBoard.fromFEN(
        'k7/8/8/8/8/8/8/K7 w - - 0 1',
        gameType: ModsEnum.mercenary,
      );

      final updated = orchestrator.updateGameStatus(board);

      expect(updated.gameStatus, equals(GameStatus.draw));
    });
  });
}
