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
