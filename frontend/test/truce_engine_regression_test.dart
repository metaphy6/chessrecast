import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Truce native regression', () {
    test(
      'does not prefer b2b3 over the stronger b2b4 space gain',
      () {
        final board = _boardFromReplay([
          'd2d4',
          'c7c5',
          'g1f3',
          'b8c6',
          'b1c3',
          'g8f6',
          'e2e4',
          'd7d5',
          'c1e3',
          'e7e5',
          'f1b5',
          'a7a6',
          'e1f1',
          'f8d6',
          'g2g4',
          'c8e6',
          'h2h3',
          'e8f8',
          'a2a3',
          'h7h6',
          'd1d3',
          'd8a5',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(root.score, greaterThan(-200));
        expect(_moveNotation(root.bestMove), 'b2b4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers d2d4 over premature Bf1d3 development',
      () {
        final board = _boardFromReplay([
          'e2e4',
          'b8c6',
          'b1c3',
          'g8f6',
          'g1f3',
          'd7d5',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(_moveNotation(root.bestMove), 'd2d4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers d2d4 over Bf1b5 in the broad-center setup',
      () {
        final board = _boardFromReplay([
          'f2f4',
          'e7e5',
          'b1c3',
          'b8c6',
          'e2e4',
          'g8f6',
          'g1f3',
          'd7d5',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(_moveNotation(root.bestMove), 'd2d4');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers c7c6 over the premature e7e5 break',
      () {
        final board = _boardFromReplay([
          'e2e3',
          'g8f6',
          'f1b5',
          'd7d5',
          'g1f3',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(_moveNotation(root.bestMove), 'c7c6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test('prefers h2h3 over mirroring with Bc1g5', () {
      final board = _boardFromReplay([
        'e2e4',
        'b8c6',
        'b1c3',
        'd7d5',
        'f1b5',
        'g8f6',
        'g1f3',
        'c8g4',
        'd2d4',
        'e7e5',
      ]);

      final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(root.score, greaterThan(-200));

    test(
      'prefers Ng1f3 over an early h-pawn shove in restrained e3-c6 structures',
      () {
        final board = _boardFromReplay([
          'e2e3',
          'c7c6',
          'b1c3',
          'g8f6',
          'f1d3',
          'd7d5',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(_moveNotation(root.bestMove), 'g1f3');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers Ng8f6 over an early queen sortie in restrained e6 structures',
      () {
        final board = _boardFromReplay([
          'b2b3',
          'e7e6',
          'c1b2',
          'b8c6',
          'g1f3',
          'f8d6',
          'e2e4',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(_moveNotation(root.bestMove), 'g8f6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'prefers active bishop development over passive Bc8d7 in b4-c6 structures',
      () {
        final board = _boardFromReplay([
          'b2b4',
          'c7c6',
          'c1b2',
          'd7d5',
          'g1f3',
          'g8f6',
          'b1c3',
          'e7e5',
          'e2e4',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(_moveNotation(root.bestMove), 'f8d6');
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'does not prefer g7g6 over the stronger g7g5 break',
      () {
        final board = _boardFromReplay([
          'c2c4',
          'g8f6',
          'b1c3',
          'd7d5',
          'g1f3',
          'b8c6',
          'd2d3',
          'e7e5',
          'c1e3',
          'c8e6',
          'g2g4',
          'f8c5',
          'f1g2',
          'e8f8',
          'b2b4',
          'd8d6',
          'a2a3',
          'a7a6',
          'h2h3',
          'b7b5',
          'd1c2',
          'h7h5',
          'e1f1',
          'h8h6',
          'h1g1',
        ]);

        final root = _rootSearch(board, timeLimitMs: 120, maxDepth: 4);

        expect(root.score, greaterThan(-200));
        expect(_moveNotation(root.bestMove), 'g7g5');
      },
      skip: !NativeEngine.isAvailable,
    );
  });
}

ChessBoard _boardFromReplay(List<String> moves) {
  final orchestrator = Orchestrator();
  var board = ChessBoard.initial(gameType: ModsEnum.truce);

  for (final notation in moves) {
    final move = orchestrator.parseAlgebraicNotation(board, notation);
    if (move == null) {
      throw StateError('Illegal Truce replay move: $notation');
    }
    board = orchestrator.executeMove(board, move);
  }

  return board;
}

NativeSearchResult _rootSearch(
  ChessBoard board, {
  required int timeLimitMs,
  required int maxDepth,
}) {
  final engine = NativeEngine();
  engine.resetState();
  return engine.findBestMoveSync(
    board,
    timeLimitMs: timeLimitMs,
    maxDepth: maxDepth,
    skillLevel: 4,
  );
}

String _moveNotation(ChessMove? move) {
  if (move == null) return '(none)';
  return move.from.algebraic + move.to.algebraic;
}
