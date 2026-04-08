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
  });
}

String _moveNotation(ChessMove? move) {
  if (move == null) return '';
  return move.from.algebraic + move.to.algebraic;
}
