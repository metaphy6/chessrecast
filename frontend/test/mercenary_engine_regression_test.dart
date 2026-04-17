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
      'avoids early Ke1-e2 drift in a stable middlegame shell',
      () {
        final board = _boardFromReplay([
          'g1f3',
          'h7g6',
          'c2d3',
          'c7d6',
          'b1c3',
          'g7f6',
          'a2b3',
          'd6e5',
          'g2h3',
          'g6f5',
          'h2g3',
          'b7b6',
          'd2e3',
          'e7e6',
          'b3c4',
          'd7d6',
          'f3e5',
          'f6e5',
          'b2b3',
          'g8f6',
          'g3f4',
          'c8b7',
          'e2f3',
          'b6c5',
          'f4e5',
          'd6e5',
          'c4c5',
          'f8c5',
          'b3c4',
          'c5e7',
          'd3d4',
          'b8d7',
        ]);

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final root = engine.findBestMoveSync(
          board,
          timeLimitMs: 1200,
          maxDepth: 7,
          skillLevel: 4,
        );

        expect(_moveNotation(root.bestMove), isNot('e1e2'));

        final analysis = _analyzePosition(board);
        final kingDrift = analysis.byNotation('e1e2');
        if (analysis.best != null && kingDrift != null) {
          expect(
            analysis.best!.score - kingDrift.score,
            greaterThanOrEqualTo(5),
          );
        }
      },
      skip: !NativeEngine.isAvailable,
    );

    test(
      'converts black advantage with active bishop play instead of pawn drift',
      () {
        final board = ChessBoard.fromFEN(
          '4k3/3nq3/5b2/1B4p1/2PPb3/8/2N5/1K1Q4 b',
          gameType: ModsEnum.mercenary,
        );

        final engine = NativeEngine();
        engine.resetState(clearTranspositionTable: true);
        final result = engine.findBestMoveSync(
          board,
          timeLimitMs: 1800,
          maxDepth: 8,
          skillLevel: 4,
        );

        expect(
          _moveNotation(result.bestMove),
          isIn(['e4c2', 'f6d4', 'e4g6', 'e4f5', 'e4b7']),
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

ChessBoard _boardFromReplay(List<String> replay) {
  final orchestrator = Orchestrator();
  var board = ChessBoard.initial(gameType: ModsEnum.mercenary);
  for (final notation in replay) {
    final move = orchestrator.parseAlgebraicNotation(board, notation);
    if (move == null) {
      throw StateError('Illegal Mercenary replay move: $notation');
    }
    board = orchestrator.executeMove(board, move);
  }
  return board;
}

int _scoreMove(NativeEngine engine, ChessBoard childBoard) {
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
