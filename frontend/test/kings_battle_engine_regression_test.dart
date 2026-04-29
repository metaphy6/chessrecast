import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kings Battle native regression', () {
    test('stabilizes with b7-b6 in the c3-e5 line', () {
      final board = _boardFromReplay([
        'c2c3',
        'e7e5',
        'e2e3',
        'e8e7',
        'e1e2',
        'e7e6',
        'e2d3',
        'e6d5',
        'c3c4',
        'd5c5',
        'd3e4',
      ]);
      final best = _rootBestMove(board);

      expect(best, isNotNull);
      expect(_moveNotation(best), isNot('h7h6'));
      expect(_moveNotation(best), 'b7b6');
    }, skip: !NativeEngine.isAvailable);

    test(
      'keeps the f-pawn lever in the f4-b5 phase-1 line',
      () {
        final board = _boardFromReplay([
          'f2f4',
          'b7b5',
          'e1f2',
          'e7e5',
          'f4e5',
          'd7d5',
          'c2c3',
          'e8d7',
          'd2d4',
          'd7c6',
          'e2e4',
          'd5e4',
          'd4d5',
          'c6b6',
          'f2e3',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'f7f5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'finds the forcing c-pawn break in the b4-f5 line',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'f7f5',
          'c2c3',
          'e8f7',
          'g2g3',
          'f7e6',
          'f2f4',
          'e6d5',
          'e1f2',
          'd5e4',
        ]);
        final analysis = _analyzePosition(board);
        final forcingBreak = analysis.byNotation('c3c4');
        final quietPrep = analysis.byNotation('d2d3');

        expect(analysis.best, isNotNull);
        expect(forcingBreak, isNotNull);
        expect(quietPrep, isNotNull);
        expect(_moveNotation(analysis.best!.move), 'c3c4');
        expect(
          forcingBreak!.score - quietPrep!.score,
          greaterThanOrEqualTo(500),
        );
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'captures c5 instead of drifting with the h-pawn',
      () {
        final board = _boardFromReplay([
          'd2d3',
          'c7c5',
          'e1d2',
          'd7d6',
          'd2c3',
          'b7b5',
          'e2e4',
          'e8d7',
          'g2g3',
          'd7e6',
          'b2b4',
          'g7g6',
          'b4c5',
        ]);
        final analysis = _analyzePosition(board);
        final capture = analysis.byNotation('d6c5');
        final pawnDrift = analysis.byNotation('h7h5');

        expect(analysis.best, isNotNull);
        expect(capture, isNotNull);
        expect(pawnDrift, isNotNull);
        expect(_moveNotation(analysis.best!.move), 'd6c5');
        expect(capture!.score - pawnDrift!.score, greaterThanOrEqualTo(200));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'finds a phase-1 capture instead of drifting with c7-c6',
      () {
        final board = _boardFromReplay([
          'd2d3',
          'f7f5',
          'e1d2',
          'f5f4',
          'd2c3',
          'e7e5',
          'c3c4',
          'd7d5',
          'c4c3',
          'e8d7',
          'e2e3',
          'd7e6',
          'a2a3',
          'd5d4',
          'c3c4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('c7c6'));
        expect(_moveNotation(best), anyOf('d4e3', 'f4e3'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'captures the advanced d-pawn instead of a quiet wing move',
      () {
        final board = _boardFromReplay([
          'c2c3',
          'c7c5',
          'e2e3',
          'd7d6',
          'e1e2',
          'e8d7',
          'e2d3',
          'd7e6',
          'd3e4',
          'g7g5',
          'd2d4',
          'f7f5',
          'e4f3',
          'c5d4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('a2a3'));
        expect(_moveNotation(best), anyOf('c3d4', 'e3d4'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays e7e5 instead of Kc6d6 in the a5-b5 phase-1 race',
      () {
        final board = _boardFromReplay([
          'e2e3',
          'b7b5',
          'e1e2',
          'd7d5',
          'e2d3',
          'e8d7',
          'd3d4',
          'd7e6',
          'c2c3',
          'g7g6',
          'b2b4',
          'f7f6',
          'd2d3',
          'e6d6',
          'e3e4',
          'd5e4',
          'd3e4',
          'd6c6',
          'h2h3',
          'a7a5',
          'b4a5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'e7e5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays e2e3 instead of g4xf5 in the d4-f5 phase-1 structure',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'f7f5',
          'e1d2',
          'e8f7',
          'd2e3',
          'f7e6',
          'e3f4',
          'g7g6',
          'g2g4',
          'e6d6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'e2e3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays c7c5 instead of d5xc4 in the d3-d5 phase-1 center knot',
      () {
        final board = _boardFromReplay([
          'd2d3',
          'd7d5',
          'e1d2',
          'e8d7',
          'd2e3',
          'd7e6',
          'g2g3',
          'f7f6',
          'e3d4',
          'g7g5',
          'c2c3',
          'e6d6',
          'c3c4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'c7c5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays c2c3 instead of Ke3f4 in the d4-f5 phase-1 king-race node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'f7f5',
          'e1d2',
          'e8f7',
          'd2e3',
          'f7e6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'c2c3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays d7d5 instead of c5xd4 in the c5-e6 phase-1 center node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'c7c5',
          'e1d2',
          'e7e6',
          'd2e3',
          'e8e7',
          'e3e4',
          'e7f6',
          'e2e3',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'd7d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays f7f5 instead of Kd6c6 in the f4-e5 phase-1 king-race node',
      () {
        final board = _boardFromReplay([
          'f2f4',
          'e7e5',
          'e1f2',
          'e8e7',
          'f2e3',
          'e7d6',
          'e3e4',
          'g7g6',
          'd2d3',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'f7f5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays e2e4 instead of f4xe5 in the post-f7f5 phase-1 continuation',
      () {
        final board = _boardFromReplay([
          'f2f4',
          'e7e5',
          'e1f2',
          'e8e7',
          'f2e3',
          'e7d6',
          'e3e4',
          'g7g6',
          'd2d3',
          'f7f5',
          'e4f3',
          'd6d5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'e2e4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays f7f6 instead of Kc6d6 in the c4-e5 phase-1 race node',
      () {
        final board = _boardFromReplay([
          'c2c4',
          'e7e5',
          'd2d3',
          'e8e7',
          'e1d2',
          'e7d6',
          'd2e3',
          'b7b6',
          'g2g3',
          'd6c6',
          'e3e4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'f7f6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays d7d5 instead of f6xe5 in the c4-e5 phase-1 follow-up',
      () {
        final board = _boardFromReplay([
          'c2c4',
          'e7e5',
          'd2d3',
          'e8e7',
          'e1d2',
          'e7d6',
          'd2e3',
          'b7b6',
          'g2g3',
          'd6c6',
          'e3e4',
          'f7f6',
          'f2f3',
          'a7a5',
          'f3f4',
          'c6c5',
          'e2e3',
          'c7c6',
          'f4e5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'd7d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays h5h4 instead of Ke6f5 in the b4-d5 phase-1 king-race node',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'd7d5',
          'd2d3',
          'e8d7',
          'e1d2',
          'd7e6',
          'd2c3',
          'e6e5',
          'f2f4',
          'e5f6',
          'c3d4',
          'g7g6',
          'c2c3',
          'h7h5',
          'e2e3',
          'f6e6',
          'd4c5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'h5h4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays f7f5 instead of Ke6f6 in the b4-c5 phase-1 center node',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'c7c5',
          'd2d4',
          'd7d6',
          'e1d2',
          'e8d7',
          'b4c5',
          'd6c5',
          'd2e3',
          'd7e6',
          'e3e4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'f7f5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays g7g6 instead of Ke4f4 in the b4-c5 phase-1 late continuation',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'c7c5',
          'd2d4',
          'd7d6',
          'e1d2',
          'e8d7',
          'b4c5',
          'd6c5',
          'd2e3',
          'd7e6',
          'e3e4',
          'f7f5',
          'e4d3',
          'c5d4',
          'd3c4',
          'e6e5',
          'c2c3',
          'e5e4',
          'c3d4',
          'e7e6',
          'a2a3',
          'e6e5',
          'c4c5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'g7g6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays c4c5 instead of Ke4f5 in the g4-e5 phase-1 center race',
      () {
        final board = _boardFromReplay([
          'g2g4',
          'e7e5',
          'f2f3',
          'e8e7',
          'e1f2',
          'e7d6',
          'f2e3',
          'd6d5',
          'd2d3',
          'b7b5',
          'b2b3',
          'c7c6',
          'c2c4',
          'b5c4',
          'b3c4',
          'd5e6',
          'e3e4',
          'f7f6',
          'd3d4',
          'e6d6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'c4c5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays d7d5 instead of Ke6d6 in the g4-e5 phase-1 setup node',
      () {
        final board = _boardFromReplay([
          'g2g4',
          'e7e5',
          'f2f3',
          'e8e7',
          'e1f2',
          'e7d6',
          'f2e3',
          'd6d5',
          'd2d3',
          'b7b5',
          'b2b3',
          'c7c6',
          'c2c4',
          'b5c4',
          'b3c4',
          'd5e6',
          'e3e4',
          'f7f6',
          'd3d4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'd7d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays d6d5 instead of g5xf4 in the g4-c5 phase-1 center structure',
      () {
        final board = _boardFromReplay([
          'g2g4',
          'c7c5',
          'f2f3',
          'd7d6',
          'e1f2',
          'e8d7',
          'f2e3',
          'd7e6',
          'e3e4',
          'g7g6',
          'd2d3',
          'f7f6',
          'e2e3',
          'g6g5',
          'f3f4',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'd6d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays d4d5 instead of Kc4c5 in the b4-c5 phase-1 late king race',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'c7c5',
          'd2d4',
          'd7d6',
          'e1d2',
          'e8d7',
          'b4c5',
          'd6c5',
          'd2e3',
          'd7e6',
          'e3e4',
          'f7f5',
          'e4d3',
          'c5d4',
          'd3c4',
          'e6e5',
          'c2c3',
          'e5e4',
          'c3d4',
          'e7e6',
          'a2a3',
          'e6e5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'd4d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays f2f3 instead of g4g5 after g2g4 d7d5',
      () {
        final board = _boardFromReplay(['g2g4', 'd7d5']);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'f2f3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays f7f6 instead of Kc5b4 in the g4-b5 phase-1 king race',
      () {
        final board = _boardFromReplay([
          'g2g4',
          'b7b5',
          'e2e3',
          'd7d6',
          'e1e2',
          'e8d7',
          'e2f3',
          'd7c6',
          'f3f4',
          'e7e5',
          'f4e4',
          'c6c5',
          'e4f5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'f7f6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays e2e3 instead of a2a3 in the b4-c5 phase-1 late simplification',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'c7c5',
          'd2d4',
          'd7d6',
          'e1d2',
          'e8d7',
          'b4c5',
          'd6c5',
          'd2e3',
          'd7e6',
          'e3e4',
          'f7f5',
          'e4d3',
          'c5d4',
          'd3c4',
          'e6e5',
          'c2c3',
          'e5e4',
          'c3d4',
          'e7e6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'e2e3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays d2d4 instead of b4xc5 in the f3-f5 phase-1 center bind',
      () {
        final board = _boardFromReplay([
          'f2f3',
          'f7f5',
          'e1f2',
          'e8f7',
          'f2e3',
          'f7e6',
          'e3d4',
          'd7d6',
          'c2c3',
          'c7c5',
          'd4c4',
          'e6e5',
          'b2b4',
          'e7e6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'd2d4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays f2f3 instead of d4d5 in the post-e2e3 b4-c5 continuation',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'c7c5',
          'd2d4',
          'd7d6',
          'e1d2',
          'e8d7',
          'b4c5',
          'd6c5',
          'd2e3',
          'd7e6',
          'e3e4',
          'f7f5',
          'e4d3',
          'c5d4',
          'd3c4',
          'e6e5',
          'c2c3',
          'e5e4',
          'c3d4',
          'e7e6',
          'e2e3',
          'e6e5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'f2f3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays g2g4 instead of e4xf5 in the f3-f5 late counter-race',
      () {
        final board = _boardFromReplay([
          'f2f3',
          'f7f5',
          'e1f2',
          'e8f7',
          'f2e3',
          'f7e6',
          'e3d4',
          'd7d6',
          'c2c3',
          'c7c5',
          'd4c4',
          'e6e5',
          'b2b4',
          'e7e6',
          'd2d4',
          'c5d4',
          'c3d4',
          'e5f4',
          'h2h4',
          'd6d5',
          'c4d3',
          'f4g3',
          'e2e4',
          'g3h2',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'g2g4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'plays g3g4 instead of b4xc5 in the f3-c5 phase-1 center race',
      () {
        final board = _boardFromReplay([
          'f2f3',
          'c7c5',
          'e1f2',
          'e7e5',
          'f2e3',
          'e8e7',
          'd2d3',
          'e7d6',
          'g2g3',
          'b7b6',
          'e3e4',
          'g7g6',
          'a2a3',
          'd6e6',
          'c2c3',
          'f7f5',
          'e4e3',
          'e6d5',
          'c3c4',
          'd5d6',
          'b2b4',
          'd6c6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'g3g4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qd1-b3 over the bishop sortie in the unlocked c5-g6 line',
      () {
        final board = _boardFromReplay([
          'e2e3',
          'f7f5',
          'e1e2',
          'e8f7',
          'e2d3',
          'f7f6',
          'b2b3',
          'f6e5',
          'f2f4',
          'e5d5',
          'e3e4',
          'd5d6',
          'g2g3',
          'g7g6',
          'e4f5',
          'd6d5',
          'f5g6',
          'h7g6',
          'a2a4',
          'd7d6',
          'c2c4',
          'd5c5',
          'b3b4',
          'c5b4',
          'b4c5',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'd1b3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qb5xd5 over Qb5-c5 in the unlocked c5-g6 continuation',
      () {
        final board = _boardFromReplay([
          'e2e3',
          'f7f5',
          'e1e2',
          'e8f7',
          'e2d3',
          'f7f6',
          'b2b3',
          'f6e5',
          'f2f4',
          'e5d5',
          'e3e4',
          'd5d6',
          'g2g3',
          'g7g6',
          'e4f5',
          'd6d5',
          'f5g6',
          'h7g6',
          'a2a4',
          'd7d6',
          'c2c4',
          'd5c5',
          'b3b4',
          'c5b4',
          'b4c5',
          'd1b3',
          'c8f5',
          'd3e3',
          'd8d7',
          'd2d4',
          'c5c6',
          'f1g2',
          'd6d5',
          'b3b5',
          'c6d6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'b5d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'keeps the black king tucked with Kc6-b6 in the unlocked f3-f5 line',
      () {
        final board = _boardFromReplay([
          'f2f3',
          'f7f5',
          'e1f2',
          'e7e5',
          'f2e3',
          'e8f7',
          'g2g3',
          'f7e6',
          'a2a3',
          'e6d5',
          'e3d3',
          'g7g6',
          'e2e4',
          'f5e4',
          'd3e3',
          'e4f3',
          'd2d4',
          'd5d6',
          'e3f3',
          'd4e5',
          'd6c6',
          'b1c3',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), 'c6b6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'keeps an active king route instead of drifting with the b-pawn in the c3-d5 line',
      () {
        final board = _boardFromReplay([
          'c2c3',
          'd7d5',
          'd2d4',
          'e8d7',
          'e2e3',
          'e7e5',
          'e1e2',
          'e5e4',
          'f2f3',
          'g7g6',
          'f3e4',
          'd5e4',
          'c3c4',
          'd7c6',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), anyOf('e2f2', 'e2d2'));
      },
      skip: !NativeEngine.isAvailable,
    );
  });
}

class _ScoredMove {
  final ChessMove move;
  final int score;

  const _ScoredMove(this.move, this.score);
}

class _PositionAnalysis {
  final List<_ScoredMove> moves;

  const _PositionAnalysis(this.moves);

  _ScoredMove? get best => moves.isEmpty ? null : moves.first;

  _ScoredMove? byNotation(String notation) {
    for (final item in moves) {
      if (_moveNotation(item.move) == notation) return item;
    }
    return null;
  }
}

_PositionAnalysis _analyzePosition(ChessBoard board) {
  final engine = NativeEngine();
  final orchestrator = Orchestrator();
  final scored = <_ScoredMove>[];

  for (final move in orchestrator.getAllValidMoves(board)) {
    final child = orchestrator.executeMove(board, move);
    final score = _scoreMove(
      engine,
      mover: board.currentPlayer,
      childBoard: child,
    );
    scored.add(_ScoredMove(move, score));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return _PositionAnalysis(scored);
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

ChessBoard _boardFromReplay(List<String> replay) {
  final orchestrator = Orchestrator();
  var board = ChessBoard.initial(gameType: ModsEnum.kingsBattle);

  for (final notation in replay) {
    final move = _parseCoordinateMove(orchestrator, board, notation);
    expect(
      move,
      isNotNull,
      reason: 'Illegal Kings Battle replay move: $notation',
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

int _scoreMove(
  NativeEngine engine, {
  required PieceColor mover,
  required ChessBoard childBoard,
}) {
  if (childBoard.gameStatus == GameStatus.checkmate) {
    return mateScore;
  }
  if (childBoard.gameStatus == GameStatus.draw ||
      childBoard.gameStatus == GameStatus.stalemate) {
    return 0;
  }

  engine.resetState();
  final reply = engine.findBestMoveSync(
    childBoard,
    timeLimitMs: 500,
    maxDepth: 6,
    skillLevel: 4,
  );
  return childBoard.currentPlayer == mover ? reply.score : -reply.score;
}

String _moveNotation(ChessMove? move) {
  if (move == null) return '(none)';
  return move.from.algebraic + move.to.algebraic;
}
