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
        final best = _rootBestMove(board);

        expect(best, isNotNull);
        expect(_moveNotation(best), isNot('e1d2'));
        expect(_moveNotation(best), 'f1e2');
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
