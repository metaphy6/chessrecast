import 'package:flutter_test/flutter_test.dart';

import 'package:chessrecast/board/board.dart';

void main() {
  test('toNativeFEN preserves castling rights, en-passant, and clocks', () {
    const fen =
        'r3k2r/pp1n1ppp/2p1bn2/3pP3/3P4/2N1BN2/PP3PPP/R3K2R w KQkq d6 7 14';
    final board = ChessBoard.fromFEN(fen);

    expect(
      board.toFEN(),
      'r3k2r/pp1n1ppp/2p1bn2/3pP3/3P4/2N1BN2/PP3PPP/R3K2R w',
    );
    expect(board.toNativeFEN(), fen);
  });

  test(
    'toNativeFEN emits dash fields when castling and ep are unavailable',
    () {
      const fen = '8/8/8/8/8/8/8/8 b - - 0 1';
      final board = ChessBoard.fromFEN(fen);

      expect(board.toNativeFEN(), fen);
    },
  );
}
