import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/evaluation.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/mods_enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kings Battle native regression', () {
    test(
      'avoids the mate-losing h-pawn drift in the c3-e5 line',
      () {
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
        expect(_moveNotation(best), anyOf('f7f6', 'b7b5', 'c5c4'));
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
        expect(capture!.score - pawnDrift!.score, greaterThanOrEqualTo(500));
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
