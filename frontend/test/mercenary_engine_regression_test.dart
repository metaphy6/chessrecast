import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mercenary native regression', () {
    test(
      'avoids catastrophic Qa4 king-safety blunder',
      () {
        final board = ChessBoard.fromFEN(
          'r2qkb1r/p4p2/2npp1p1/2p5/2P1PP2/2P5/4B2P/RNBQK2R w',
          gameType: ModsEnum.mercenary,
        );

        final analysis = _analyzePosition(board);
        final best = analysis.best;
        final blunder = analysis.byNotation('d1a4');

        expect(best, isNotNull);
        expect(blunder, isNotNull);
        expect(
          best!.move.from.algebraic + best.move.to.algebraic,
          isNot('d1a4'),
        );
        expect(best.score - blunder!.score, greaterThanOrEqualTo(250));
        expect(blunder.score, lessThan(0));
      },
      skip: !NativeEngine.isAvailable,
    );

    test('prefers safe recapture over Qxd4', () {
      final board = ChessBoard.fromFEN(
        'r1b1k2r/p1q1bp2/1p2p1p1/5p2/2PnP3/4PNP1/1B3KBP/R2Q3R w',
        gameType: ModsEnum.mercenary,
      );

      final analysis = _analyzePosition(board);
      final queenRecapture = analysis.byNotation('d1d4');
      final knightRecapture = analysis.byNotation('f3d4');

      expect(queenRecapture, isNotNull);
      expect(knightRecapture, isNotNull);
      expect(
        knightRecapture!.score - queenRecapture!.score,
        greaterThanOrEqualTo(150),
      );
      expect(queenRecapture.score, lessThan(0));
    }, skip: !NativeEngine.isAvailable);

    test(
      'converts black advantage with active bishop play instead of pawn drift',
      () {
        final board = ChessBoard.fromFEN(
          '4k3/3nq3/5b2/1B4p1/2PPb3/8/2N5/1K1Q4 b',
          gameType: ModsEnum.mercenary,
        );

        final result = NativeEngine().findBestMoveSync(
          board,
          timeLimitMs: 1800,
          maxDepth: 8,
          skillLevel: 4,
        );

        expect(
          _moveNotation(result.bestMove),
          isIn(['e4c2', 'f6d4', 'e4g6', 'e4f5']),
        );
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
      final moveNotation = item.move.from.algebraic + item.move.to.algebraic;
      if (moveNotation == notation) return item;
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
    final score = _scoreMove(engine, child);
    scored.add(_ScoredMove(move, score));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));
  return _PositionAnalysis(scored);
}

int _scoreMove(NativeEngine engine, ChessBoard childBoard) {
  if (childBoard.gameStatus == GameStatus.checkmate) {
    return mateScore;
  }
  if (childBoard.gameStatus == GameStatus.draw ||
      childBoard.gameStatus == GameStatus.stalemate) {
    return 0;
  }

  final reply = engine.findBestMoveSync(
    childBoard,
    timeLimitMs: 150,
    maxDepth: math.max(1, 4 - 1),
    skillLevel: 4,
  );
  return -reply.score;
}

String _moveNotation(ChessMove? move) {
  if (move == null) return '';
  return move.from.algebraic + move.to.algebraic;
}
