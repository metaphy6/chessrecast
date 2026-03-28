import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/evaluation.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/mods_enum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Heir native regression', () {
    test(
      'prefers king retreat over exposed queen shuffle',
      () {
        final board = ChessBoard.fromFEN(
          'r2qkb1r/1pp2ppp/4p3/p3Pb2/1n1Pp3/2N1Q3/PPP1N1PP/R1B1KB1R w',
          gameType: ModsEnum.heir,
        );

        final analysis = _analyzePosition(board);
        final best = analysis.best;
        final queenRetreat = analysis.byNotation('e3d2');

        expect(best, isNotNull);
        expect(queenRetreat, isNotNull);
        expect(_moveNotation(best!.move), isIn(['e1d1', 'e1d2']));
        expect(best.score - queenRetreat!.score, greaterThanOrEqualTo(120));
      },
      skip: !NativeEngine.isAvailable,
    );

    test('finds tactical knight capture on e5', () {
      final board = ChessBoard.fromFEN(
        'r2qkbnr/ppp2ppp/2n5/4p3/3p1Bb1/1QPP1N2/PP2PPPP/RN2KB1R w',
        gameType: ModsEnum.heir,
      );

      final analysis = _analyzePosition(board);
      final knightCapture = analysis.byNotation('f3e5');
      final bishopCapture = analysis.byNotation('f4e5');

      expect(knightCapture, isNotNull);
      expect(bishopCapture, isNotNull);
      expect(analysis.best, isNotNull);
      expect(_moveNotation(analysis.best!.move), 'f3e5');
      expect(
        knightCapture!.score - bishopCapture!.score,
        greaterThanOrEqualTo(120),
      );
    }, skip: !NativeEngine.isAvailable);

    test(
      'captures the hanging bishop instead of retreating',
      () {
        final board = ChessBoard.fromFEN(
          'r1bqk2r/ppp2ppp/2n5/2b1p3/1B2P3/3P1N2/PP3PPP/RN1QKB1R b',
          gameType: ModsEnum.heir,
        );

        final analysis = _analyzePosition(board);
        final retreat = analysis.byNotation('c5f8');

        expect(analysis.best, isNotNull);
        expect(retreat, isNotNull);
        expect(_moveNotation(analysis.best!.move), isIn(['c5b4', 'c6b4']));
        expect(
          analysis.best!.score - retreat!.score,
          greaterThanOrEqualTo(180),
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
    timeLimitMs: 1800,
    maxDepth: 8,
    skillLevel: 4,
  );
  return -reply.score;
}

String _moveNotation(ChessMove? move) {
  if (move == null) return '(none)';
  return move.from.algebraic + move.to.algebraic;
}
