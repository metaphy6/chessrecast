import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Save the Queen native regression', () {
    test(
      'treats capturing an escaped queen as an immediate win',
      () {
        final board = ChessBoard.fromFEN(
          '6k1/8/8/4q3/8/8/4R3/6K1 w - - 0 1',
          gameType: ModsEnum.saveTheQueen,
        );

        final result = NativeEngine().findBestMoveSync(
          board,
          timeLimitMs: 200,
          maxDepth: 5,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'e2e5');
        expect(isMateScore(result.score), isTrue);
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers d3xe4 in the GAME 10 tactical node',
      () {
        final board = ChessBoard.fromFEN(
          'N1b2bkr/pp1pp1pp/1Q6/4Np2/4nP2/1q1P4/PP2PKPP/n1B2B1R w',
          gameType: ModsEnum.saveTheQueen,
        );

        final result = NativeEngine().findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        expect(result.score, greaterThan(-300));
        expect(_moveNotation(result.bestMove), 'd3e4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers a2xb3 in the GAME 19 tactical node',
      () {
        final board = ChessBoard.fromFEN(
          'N1b2bnr/ppQpkppp/8/4p3/8/1q1P1N2/PP1KPPPP/n1B2B1R w',
          gameType: ModsEnum.saveTheQueen,
        );

        final result = NativeEngine().findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        expect(result.score, greaterThan(-400));
        expect(_moveNotation(result.bestMove), 'a2b3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers a2-a3 in the GAME 30 opening-prison-walk node',
      () {
        final board = _boardFromReplay([
          'e2e3',
          'c7c5',
          'd8c7',
          'e7e6',
          'b1c3',
          'b8c6',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-300));
        expect(_moveNotation(search.bestMove), 'a2a3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers a7-a6 in the GAME 8/9 opening node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'g8f6',
          'g1f3',
          'b8c6',
          'c1d2',
          'b7b5',
          'b1c3',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-400));
        expect(_moveNotation(search.bestMove), 'a7a6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Be7-c5 in the GAME 34 midgame node',
      () {
        final board = _boardFromReplay([
          'd2d3',
          'b8c6',
          'g1f3',
          'c6b4',
          'b1a3',
          'g8f6',
          'c1d2',
          'a7a5',
          'f3d4',
          'e7e5',
          'd4b5',
          'b4d5',
          'e2e4',
          'f8e7',
          'a3c4',
          'd5b4',
          'b5c7',
          'e8f8',
          'a1c1',
          'a8b8',
          'c4b6',
          'b4a2',
          'c1b1',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-400));
        expect(_moveNotation(search.bestMove), 'e7c5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers b2-b3 over Qd8-d7 in the GAME 34 opening node',
      () {
        final board = _boardFromReplay([
          'f2f4',
          'd7d5',
          'b1c3',
          'g8f6',
          'g1f3',
          'c8d7',
          'f3d4',
          'b8c6',
          'c3b5',
          'a8c8',
          'd4c6',
          'b7c6',
          'b5d4',
          'c6c5',
          'd4f3',
          'd7f5',
          'f3e5',
          'c5c4',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'b2b3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers e2-e3 over Qd8-d7 in the GAME 34 follow-up node',
      () {
        final board = _boardFromReplay([
          'f2f4',
          'd7d5',
          'b1c3',
          'g8f6',
          'g1f3',
          'c8d7',
          'f3d4',
          'b8c6',
          'c3b5',
          'a8c8',
          'd4c6',
          'b7c6',
          'b5d4',
          'c6c5',
          'd4f3',
          'd7f5',
          'f3e5',
          'c5c4',
          'b2b3',
          'f6d7',
          'b3c4',
          'd7e5',
          'f4e5',
          'd5c4',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'e2e3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers c4xd3 over Qd1-c2 in the GAME 38 tactical node',
      () {
        final board = _boardFromReplay([
          'd2d3',
          'd7d5',
          'g1f3',
          'g8f6',
          'g2g3',
          'c7c5',
          'd8c7',
          'b7b6',
          'f3e5',
          'b8a6',
          'c7c6',
          'a6c7',
          'c1f4',
          'c7b5',
          'c2c4',
          'd5c4',
          'f1g2',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'c4d3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Bc8-d7 over Qd1-e2 in the GAME 29 tactical node',
      () {
        final board = _boardFromReplay([
          'g1f3',
          'd7d5',
          'c2c4',
          'd5c4',
          'e2e4',
          'g8f6',
          'b1c3',
          'b8a6',
          'e4e5',
          'f6g4',
          'f1c4',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'c8d7');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Ke1-g1 over Qd8-c7 in the GAME 50 opening node',
      () {
        final board = _boardFromReplay([
          'g1f3',
          'g8f6',
          'g2g3',
          'g7g6',
          'f1g2',
          'f8g7',
          'c2c4',
          'd7d6',
          'b1c3',
          'c7c5',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'e1g1');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qd1-c2 over Qd1-e2 in the GAME 50 follow-up node',
      () {
        final board = _boardFromReplay([
          'g1f3',
          'g8f6',
          'g2g3',
          'g7g6',
          'f1g2',
          'f8g7',
          'c2c4',
          'd7d6',
          'b1c3',
          'c7c5',
          'e1g1',
          'b8a6',
          'f3e1',
          'a6c7',
          'e1c2',
          'f6g4',
          'f2f3',
          'g4f6',
          'f1e1',
          'c8f5',
          'e2e4',
          'f5d7',
          'g3g4',
          'g6g5',
          'c3d5',
          'f6d5',
          'e4d5',
          'a8c8',
          'g1f2',
          'd7a4',
          'c2e3',
          'g7d4',
          'f2f1',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'd1c2');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qd8-c7 over Qd8-e7 in the GAME 31 tactical node',
      () {
        final board = _boardFromReplay([
          'g1f3',
          'd7d5',
          'g2g3',
          'c7c5',
          'f1g2',
          'b8c6',
          'e1g1',
          'g8f6',
          'f1e1',
          'e7e5',
          'd2d3',
          'c6b4',
          'b1a3',
          'd1d2',
          'f3d2',
          'c8d7',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'd8c7');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers c6xd5 over Qd1-c2 in the GAME 18 tactical node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'd7d5',
          'c2c4',
          'c7c6',
          'c4d5',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'c6d5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers e7-e6 over Qd1-c2 in the GAME 18 follow-up node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'd7d5',
          'c2c4',
          'c7c6',
          'c4d5',
          'c6d5',
          'd8c7',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'e7e6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Ng1-f3 over Nb1-a3 in the GAME 18 post-e7e6 node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'd7d5',
          'c2c4',
          'c7c6',
          'c4d5',
          'c6d5',
          'd8c7',
          'e7e6',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'g1f3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'treats reaching opponent prison with escaped queen as immediate win',
      () {
        final board = ChessBoard.fromFEN(
          '6k1/8/8/8/8/8/3Q4/6K1 w - - 0 1',
          gameType: ModsEnum.saveTheQueen,
        );

        final result = NativeEngine().findBestMoveSync(
          board,
          timeLimitMs: 200,
          maxDepth: 5,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'd2d1');
        expect(isMateScore(result.score), isTrue);
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids Qd1-e2 in the b1c3,b7b6 tactical branch',
      () {
        final board = _boardFromReplay([
          'b1c3',
          'b7b6',
          'c3d5',
          'b8a6',
          'e2e4',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-200));
        expect(_moveNotation(search.bestMove), isNot('d1e2'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids Nb8-c6 in the e2e4,e7e5 early branch',
      () {
        final board = _boardFromReplay([
          'e2e4',
          'e7e5',
          'b1c3',
          'g8e7',
          'g1e2',
        ]);
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('b8c6'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Bc8-d7 when defending the checked king branch',
      () {
        final board = ChessBoard.fromFEN(
          'r1b1k2r/pp3p1p/1Q6/1B1p1p2/1b1p4/8/1PPP1PPP/R1BqK2R b',
          gameType: ModsEnum.saveTheQueen,
        );
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-200));
        expect(_moveNotation(search.bestMove), 'c8d7');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Bf4-e5 in the GAME 11 opening regression node',
      () {
        final board = _boardFromReplay([
          'g1f3',
          'e7e5',
          'f3e5',
          'f8d6',
          'f2f4',
          'g8e7',
          'b1c3',
          'b8c6',
          'e5c6',
          'e7c6',
          'c3b5',
          'd6f4',
          'e2e3',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-500));
        expect(_moveNotation(search.bestMove), 'f4e5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Nd7-e5 in the GAME 22 opening regression node',
      () {
        final board = _boardFromReplay([
          'c2c4',
          'd7d5',
          'e2e3',
          'd5c4',
          'f1c4',
          'b8d7',
          'b1a3',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-500));
        expect(_moveNotation(search.bestMove), 'd7e5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers d4xc5 in the GAME 22 tactical node',
      () {
        final board = _boardFromReplay(['d2d4', 'g8f6', 'c2c4', 'c7c5']);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'd4c5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Nb1-c3 in the GAME 22 tactical follow-up node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'g8f6',
          'c2c4',
          'c7c5',
          'd4c5',
          'b8a6',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'b1c3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Nd7-b6 in the GAME 23 tactical node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'd7d5',
          'c2c4',
          'e7e6',
          'b1c3',
          'g8f6',
          'c1g5',
          'f8e7',
          'e2e3',
          'e8g8',
          'g5f6',
          'e7f6',
          'c4d5',
          'b8d7',
          'c3b5',
          'a8b8',
          'b5c7',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'd7b6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Nb6-c8 in the GAME 23 tactical follow-up node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'd7d5',
          'c2c4',
          'e7e6',
          'b1c3',
          'g8f6',
          'c1g5',
          'f8e7',
          'e2e3',
          'e8g8',
          'g5f6',
          'e7f6',
          'c4d5',
          'b8d7',
          'c3b5',
          'a8b8',
          'b5c7',
          'd7b6',
          'd5d6',
          'c8d7',
          'f1d3',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'b6c8');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids Qd1-c2 in the GAME 20 opening-principle node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'g8f6',
          'c2c4',
          'e7e6',
          'g1f3',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), isNot('d1c2'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids Ke8-e7 in the GAME 20 follow-up node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'g8f6',
          'c2c4',
          'e7e6',
          'g1f3',
          'f8b4',
          'c1d2',
          'b8a6',
          'b1c3',
          'd1c2',
          'b2b3',
          'b4c3',
          'd2c3',
          'f6e4',
          'c3a5',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), isNot('e8e7'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Bc8-b7 in the GAME 3 opening regression node',
      () {
        final board = _boardFromReplay([
          'e2e4',
          'g8f6',
          'b1c3',
          'b8a6',
          'f1a6',
          'b7a6',
          'e4e5',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-500));
        expect(_moveNotation(search.bestMove), 'c8b7');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers f2-f3 in the GAME 3 follow-up node after Bc8-b7',
      () {
        final board = ChessBoard.fromFEN(
          'r2Qkb1r/pbpppppp/p4n2/4P3/8/2N5/PPPP1PPP/R1BqK1NR w',
          gameType: ModsEnum.saveTheQueen,
        );
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-500));
        expect(_moveNotation(search.bestMove), 'f2f3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Na6-b4 in the GAME 10 tactical node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'c7c5',
          'd4c5',
          'b8a6',
          'c1f4',
          'a6b4',
          'b1a3',
          'e7e6',
          'f4e3',
          'b4a6',
          'a3b5',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-250));
        expect(_moveNotation(search.bestMove), 'a6b4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qd4-e4 in the GAME 15 tactical node',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'g8f6',
          'c2c4',
          'g7g6',
          'b1c3',
          'f8g7',
          'e2e4',
          'd7d6',
          'g1f3',
          'e8g8',
          'e4e5',
          'd6e5',
          'd4e5',
          'f6d7',
          'c3d5',
          'b8c6',
          'd5c7',
          'a8b8',
          'e5e6',
          'd7c5',
          'e6f7',
          'g8f7',
          'c7d5',
          'd1c2',
          'f1e2',
          'c2d3',
          'c1e3',
          'd3d4',
          'e1g1',
          'e7e6',
          'd5c3',
          'c8d7',
          'b2b4',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'd4e4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Ke1xe2 in the GAME 21 blunder node',
      () {
        final board = _boardFromReplay([
          'c2c4',
          'e7e5',
          'e2e3',
          'g8e7',
          'f1d3',
          'b8c6',
          'g1f3',
          'f7f5',
          'd3c2',
          'e5e4',
          'f3d4',
          'c6d4',
          'e3d4',
          'e7c6',
          'd4d5',
          'c6d4',
          'c2a4',
          'd1e2',
          'd2d3',
          'e4d3',
          'c1g5',
          'd4c2',
          'a4c2',
          'd3c2',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-500));
        expect(_moveNotation(search.bestMove), 'e1e2');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Qe2-f3 in the GAME 21 residual node',
      () {
        final board = _boardFromReplay([
          'c2c4',
          'e7e5',
          'e2e3',
          'g8e7',
          'f1d3',
          'b8c6',
          'g1f3',
          'f7f5',
          'd3c2',
          'e5e4',
          'f3d4',
          'c6d4',
          'e3d4',
          'e7c6',
          'd4d5',
          'c6d4',
          'c2a4',
          'd1e2',
          'd2d3',
          'e4d3',
          'c1g5',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(search.score, greaterThan(-500));
        expect(_moveNotation(search.bestMove), 'e2f3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers e6xf7 in the GAME 23 tactical shell',
      () {
        final board = ChessBoard.fromFEN(
          '1rbQ1rk1/ppNnbppp/4P3/8/1q1P4/1P1BP3/P4PPP/R3K1NR w',
          gameType: ModsEnum.saveTheQueen,
        );
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'e6f7');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Ra1-c1 over a2-a3 in the GAME 23 follow-up shell',
      () {
        final board = ChessBoard.fromFEN(
          '1rbQ4/ppNnbrpk/8/8/1q1P4/1P2P3/P4PPP/R3K1NR w',
          gameType: ModsEnum.saveTheQueen,
        );
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'a1c1');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Nb1xd2 over Ke1xd2 in the GAME 24 recapture shell',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'e7e6',
          'c2c4',
          'b7b6',
          'g1f3',
          'd1c2',
          'b2b3',
          'f8b4',
          'c1d2',
          'b8c6',
          'd4d5',
          'b4d2',
        ]);
        final search = _rootSearch(board);

        expect(search.bestMove, isNotNull);
        expect(_moveNotation(search.bestMove), 'b1d2');
      },
      skip: !NativeEngine.isAvailable,
    );

    test('prefers a2-a3 in the GAME 42 opening node', () {
      final board = _boardFromReplay([
        'b2b3',
        'd7d5',
        'b1c3',
        'g8f6',
        'g1f3',
        'c8d7',
        'b3b4',
        'b8c6',
      ]);
      final search = _rootSearch(board);

      expect(search.bestMove, isNotNull);
      expect(search.score, greaterThan(-500));
      expect(_moveNotation(search.bestMove), 'a2a3');
    }, skip: !NativeEngine.isAvailable);
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
  var board = ChessBoard.initial(gameType: ModsEnum.saveTheQueen);

  for (final notation in replay) {
    final move = _parseCoordinateMove(orchestrator, board, notation);
    expect(
      move,
      isNotNull,
      reason: 'Illegal Save the Queen replay move: $notation',
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
  final moves = orchestrator.getAllValidMoves(board);
  if (notation.length < 4) return null;

  try {
    final from = Position.fromAlgebraic(notation.substring(0, 2));
    final to = Position.fromAlgebraic(notation.substring(2, 4));
    final promotion = notation.length >= 5
        ? notation.substring(4, 5).toUpperCase()
        : null;

    for (final move in moves) {
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
  if (move == null) return '';
  return move.from.algebraic + move.to.algebraic;
}
