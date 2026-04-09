import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Succession native regression', () {
    test(
      'treats capturing an enemy queen as an immediate win',
      () {
        final board = ChessBoard.fromFEN(
          'q7/7q/8/4q3/8/8/4R3/3QQ3 w - - 0 1',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 220,
          maxDepth: 5,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'e2e5');
        expect(isMateScore(result.score), isTrue);
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers king promotion when the last pawn can promote safely',
      () {
        final board = ChessBoard.fromFEN(
          '8/p2P3p/q6q/8/8/8/2NNNN2/2BQQB2 w - - 0 1',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 220,
          maxDepth: 5,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'd7d8');
        expect(isMateScore(result.score), isTrue);
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'does not choose attacked-square king promotion for the last pawn',
      () {
        final board = ChessBoard.fromFEN(
          '8/p2P3p/q2r3q/8/8/8/2NNNN2/2BQQB2 w - - 0 1',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 220,
          maxDepth: 5,
          skillLevel: 4,
        );

        expect(result.bestMove, isNotNull);
        expect(result.score, greaterThan(-500));
        expect(_moveNotation(result.bestMove), isNot('d7d8'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids the c4-c5 overpush in the GAME 29 tactical node',
      () {
        final board = ChessBoard.fromFEN(
          'r2q3r/pppnqp1p/4p1p1/5b2/1nPPN3/3B1N2/PP3PPP/R2QQ2R w - - 0 12',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        final move = _moveNotation(result.bestMove);
        expect(move, isNot('c4c5'));
        expect(move == 'e1e3' || move == 'd3b1' || move == 'a2a3', isTrue);
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'chooses Nb5-c3 in the GAME 43 tactical node',
      () {
        final board = ChessBoard.fromFEN(
          'r1bq1b1r/1p3ppp/pqn2n2/1N1p4/2P1pP1Q/1P2P3/P3B1PP/R1BQ2NR w - - 0 13',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'b5c3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids Bc1-g5 in the GAME 6 strategic node',
      () {
        final board = ChessBoard.fromFEN(
          'r2q1b1r/ppp1n2p/2n2qp1/3p1P2/8/5N1Q/PPP3PP/RNBQ1B1R w - - 0 12',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        expect(result.score, greaterThan(-300));
        expect(_moveNotation(result.bestMove), isNot('c1g5'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'avoids Qd1-f3 queen sortie in the GAME 29 strategic node',
      () {
        final board = ChessBoard.fromFEN(
          'r2qqbr1/ppp2p1p/2n1pn2/3pNp2/3P4/P1N1P3/1PP2PPP/R1BQQ2R w - - 0 9',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        final move = _moveNotation(result.bestMove);
        expect(result.score, greaterThan(-300));
        expect(move, isNot('d1f3'));
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'chooses Ng8-f6 in the GAME 45 strategic node',
      () {
        final board = ChessBoard.fromFEN(
          'r2q2nr/p1p3pp/1pn3q1/2p1B3/2B5/1P3N2/P1bP1PPP/R1Q1Q2R b - - 0 11',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'g8f6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'chooses Bd3-b5 in the GAME 50 strategic node',
      () {
        final board = ChessBoard.fromFEN(
          'r2qqb1r/p1p3p1/1pn5/3ppb1p/1P1Pn2P/P1NBPN2/2PB2P1/R2QQ2R w - - 0 12',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'd3b5');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'chooses Qe1-c3 in the GAME 24 strategic node',
      () {
        final board = ChessBoard.fromFEN(
          'r1bq3r/ppp2p1p/3p2p1/1qbPp3/3nP3/3PBN1P/PP3PP1/R2QQB1R w - - 0 10',
          gameType: ModsEnum.succession,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 120,
          maxDepth: 4,
          skillLevel: 4,
        );

        expect(_moveNotation(result.bestMove), 'e1c3');
      },
      skip: !NativeEngine.isAvailable,
    );
  });
}

String _moveNotation(ChessMove? move) {
  if (move == null) return '';
  return move.from.algebraic + move.to.algebraic;
}
