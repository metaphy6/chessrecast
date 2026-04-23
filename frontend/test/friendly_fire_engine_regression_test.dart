import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Friendly Fire native regression', () {
    test(
      'prefers Bf1-e2 over the exposed king walk in the d4-d5 line',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'd7d5',
          'g1f3',
          'g8f6',
          'b1c3',
          'b8c6',
          'c1f4',
          'h7h6',
          'c3b5',
          'e7e5',
          'f3e5',
          'c6e7',
          'e5c6',
          'e7c6',
          'b5c7',
          'e8d7',
          'c7a8',
          'f8d6',
          'e2e3',
          'd6f4',
          'e3f4',
          'd8e8',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-200));
        expect(_moveNotation(search.bestMove), isNot('e1d2'));
        expect(_moveNotation(search.bestMove), 'f1e2');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Bb4-e7 over the king tuck in the b4-e5 line',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'e7e5',
          'b4b5',
          'g8f6',
          'b1c3',
          'd7d5',
          'd2d4',
          'f8b4',
          'c1b2',
          'f6e4',
          'd1d3',
          'd8f6',
          'g1f3',
          'e5d4',
          'f3d4',
          'b8d7',
          'f2f3',
          'f6h4',
          'g2g3',
          'e4g3',
          'd3e3',
          'e8f8',
          'e3f2',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('f8g8'));
        expect(_moveNotation(best), 'b4e7');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers a3xb4 over the passive bishop retreat in the c5-a5 line',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'c7c5',
          'd4c5',
          'e7e5',
          'c1e3',
          'b8c6',
          'g1f3',
          'g8f6',
          'b1c3',
          'd8a5',
          'a2a3',
          'f6e4',
          'b2b4',
          'c6b4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('e3d2'));
        expect(_moveNotation(best), 'a3b4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers h2-h3 over routine knight development in the g4 bishop pin line',
      () {
        final board = _boardFromReplay([
          'g2g4',
          'e7e5',
          'd2d4',
          'd7d5',
          'd4e5',
          'b8c6',
          'g4g5',
          'c8g4',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-200));
        expect(_moveNotation(search.bestMove), isNot('g1f3'));
        expect(_moveNotation(search.bestMove), 'h2h3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Ng1-f3 over the loose Nc3xd5 pawn grab in the f5 line',
      () {
        final board = _boardFromReplay([
          'e2e4',
          'f7f5',
          'e4f5',
          'g8f6',
          'f1d3',
          'd7d5',
          'd1e2',
          'c8d7',
          'b1c3',
          'b8c6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('c3d5'));
        expect(_moveNotation(best), 'g1f3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Ng8-e7 over the loose Bd6xe5 bishop capture in the b4 d5 line',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'd7d5',
          'g1f3',
          'e7e5',
          'f3e5',
          'f8b4',
          'e2e3',
          'e8f8',
          'a2a3',
          'b4d6',
          'd2d4',
          'd8f6',
          'b1c3',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('d6e5'));
        expect(_moveNotation(best), 'g8e7');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qd1xd5 over the loose e4xd5 pawn grab in the d4 c5 line',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'c7c5',
          'g1f3',
          'c5d4',
          'f3d4',
          'g8f6',
          'b1c3',
          'e7e5',
          'd4f3',
          'b8c6',
          'e2e4',
          'f8c5',
          'f1c4',
          'd8b6',
          'c3d5',
          'f6d5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('e4d5'));
        expect(_moveNotation(best), 'd1d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Rh1-f1 over the loose Qd4xe5 queen grab in the g4 e5 line',
      () {
        final board = _boardFromReplay([
          'g2g4',
          'e7e5',
          'b1c3',
          'd7d5',
          'd2d4',
          'b8c6',
          'e2e3',
          'c8e6',
          'f1b5',
          'g8f6',
          'b5c6',
          'b7c6',
          'd4e5',
          'f6e4',
          'g1e2',
          'd8h4',
          'c3e4',
          'd5e4',
          'd1d4',
          'h4g4',
          'e2c3',
          'e6f5',
          'c1d2',
          'g4g2',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-200));
        expect(_moveNotation(search.bestMove), isNot('d4e5'));
        expect(_moveNotation(search.bestMove), 'h1f1');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qd2xe3 over passive rook firebreak in the b4 e5 d4e3 line',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'e7e5',
          'b4b5',
          'd7d5',
          'd2d3',
          'g8f6',
          'b1c3',
          'f8b4',
          'c1d2',
          'b8d7',
          'g1f3',
          'd5d4',
          'c3e4',
          'b4d2',
          'd1d2',
          'e8f8',
          'e2e3',
          'd4e3',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), isNot('a1d1'));
        expect(_moveNotation(search.bestMove), 'd2e3');
      },F, Heir, Mer
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids KRK repetition reset from the e5-g4 squeeze position',
      () {
        final board = ChessBoard.fromFEN(
          '8/8/8/4K3/6k1/8/8/7R w - - 0 1',
          gameType: ModsEnum.friendlyFire,
        );
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), isNot('e5e4'));
        expect(search.bestMove!.from.algebraic, 'h1');
      },
      skip: !NativeEngine.isAvailable,
    );
  });
}

ChessMove? _rootBestMove(
  ChessBoard board, {
  int timeLimitMs = 120,
  int maxDepth = 4,
  int skillLevel = 4,
}) {
  final engine = NativeEngine();
  engine.resetState();
  return engine
      .findBestMoveSync(
        board,
        timeLimitMs: timeLimitMs,
        maxDepth: maxDepth,
        skillLevel: skillLevel,
      )
      .bestMove;
}

NativeSearchResult _rootSearch(
  ChessBoard board, {
  int timeLimitMs = 120,
  int maxDepth = 4,
  int skillLevel = 4,
}) {
  final engine = NativeEngine();
  engine.resetState();
  return engine.findBestMoveSync(
    board,
    timeLimitMs: timeLimitMs,
    maxDepth: maxDepth,
    skillLevel: skillLevel,
  );
}

ChessBoard _boardFromReplay(List<String> replay) {
  final orchestrator = Orchestrator();
  var board = ChessBoard.initial(gameType: ModsEnum.friendlyFire);

  for (final notation in replay) {
    final move = _parseCoordinateMove(orchestrator, board, notation);
    expect(
      move,
      isNotNull,
      reason: 'Illegal Friendly Fire replay move: $notation',
    );
    board = orchestrator.executeMove(board, move!);
  }

  return board;
}

ChessMove? _parseCoordinateMove(
  Orchestrator orchestrator,
  ChessBoard board,
  String notation,
) {
  if (notation.length < 4) return null;

  try {
    final from = Position.fromAlgebraic(notation.substring(0, 2));
    final to = Position.fromAlgebraic(notation.substring(2, 4));
    final promotion = notation.length >= 5
        ? notation.substring(4, 5).toUpperCase()
        : null;

    for (final move in orchestrator.getAllValidMoves(board)) {
      if (move.from != from || move.to != to) continue;
      if (promotion != null && move.promotionPiece != promotion) continue;
      if (promotion == null && move.isPromotion) continue;
      return move;
    }
  } catch (_) {
    return null;
  }

  return null;
}

String _moveNotation(ChessMove? move) {
  if (move == null) return '(none)';
  return move.from.algebraic + move.to.algebraic;
}
