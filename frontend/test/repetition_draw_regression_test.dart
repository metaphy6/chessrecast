import 'package:chessrecast/board/board.dart';
import 'package:chessrecast/mods/mods_enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Threefold repetition regression', () {
    test('does not auto-draw on the second occurrence of a position', () {
      final board = ChessBoard.fromFEN(
        '5p2/8/3pk1p1/5b2/Q1P5/2N1n3/4r2q/K4R2 b',
        gameType: ModsEnum.mercenary,
      );
      final key = board.getPositionKey();
      final twofoldBoard = board.copyWith(positionHistory: [key, key]);

      expect(twofoldBoard.hasThreefoldRepetition(), isFalse);
      expect(twofoldBoard.shouldAutoDraw(), isFalse);
    });

    test('still auto-draws on the third occurrence of a position', () {
      final board = ChessBoard.fromFEN(
        '5p2/8/3pk1p1/5b2/Q1P5/2N1n3/4r2q/K4R2 b',
        gameType: ModsEnum.mercenary,
      );
      final key = board.getPositionKey();
      final threefoldBoard = board.copyWith(positionHistory: [key, key, key]);

      expect(threefoldBoard.hasThreefoldRepetition(), isTrue);
      expect(threefoldBoard.shouldAutoDraw(), isTrue);
    });
  });
}
