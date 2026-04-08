import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';

void main(List<String> args) {
  print(runHeirPositionProbe(args));
}

String runSuccessionPositionProbe(List<String> args) {
  return runHeirPositionProbe([...args, '--mod=succession']);
}

String runHeirPositionProbe(List<String> args) {
  final fen = _readArg(args, 'fen');
  if (fen == null || fen.isEmpty) {
    throw ArgumentError('Provide --fen=<fen>');
  }

  final mode = (_readArg(args, 'mod') ?? 'heir').toLowerCase();
  final isSuccession = mode == 'succession';
  final modName = isSuccession ? 'Succession' : 'Heir';
  final gameType = isSuccession ? ModsEnum.succession : ModsEnum.heir;

  final depth = _readIntArg(args, 'depth', 6);
  final timeMs = _readIntArg(args, 'time-ms', 1200);
  final topCount = _readIntArg(args, 'top-count', 8);
  final candidateArg = _readArg(args, 'candidates') ?? '';
  final candidates = candidateArg.isEmpty
      ? const <String>[]
      : candidateArg.split(',').where((s) => s.isNotEmpty).toList();

  final board = ChessBoard.fromFEN(fen, gameType: gameType);
  final engine = NativeEngine();
  final orchestrator = Orchestrator();
  final lines = <String>[];

  lines.add('$modName probe: d$depth/${timeMs}ms');
  lines.add('FEN: $fen');
  lines.add('Side to move: ${board.currentPlayer.name}');
  lines.add('');

  final legalMoves = orchestrator.getAllValidMoves(board);
  final scored = <_ScoredMove>[];
  for (final move in legalMoves) {
    final child = orchestrator.executeMove(board, move);
    final score = _scorePlayedMove(engine, child, timeMs, depth);
    final bestReply = child.gameStatus.isGameOver
        ? null
        : (() {
            engine.resetState();
            return engine
                .findBestMoveSync(
                  child,
                  timeLimitMs: timeMs,
                  maxDepth: math.max(1, depth - 1),
                  skillLevel: 4,
                )
                .bestMove;
          })();
    scored.add(_ScoredMove(move: move, score: score, bestReply: bestReply));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));

  lines.add('Top ${math.min(topCount, scored.length)} moves:');
  for (var index = 0; index < math.min(topCount, scored.length); index++) {
    final item = scored[index];
    lines.add(
      '${index + 1}. ${_moveLabel(item.move)} '
      'score=${_cp(item.score)} '
      'reply=${_moveLabel(item.bestReply)}',
    );
  }

  if (candidates.isNotEmpty) {
    lines.add('');
    lines.add('Requested candidates:');
    for (final notation in candidates) {
      final move = orchestrator.parseAlgebraicNotation(board, notation);
      if (move == null) {
        lines.add('- $notation: not legal');
        continue;
      }
      final item = scored.firstWhere((s) => s.move == move);
      lines.add(
        '- $notation => ${_moveLabel(item.move)} '
        'score=${_cp(item.score)} '
        'reply=${_moveLabel(item.bestReply)}',
      );
    }
  }

  return lines.join('\n');
}

class _ScoredMove {
  final ChessMove move;
  final int score;
  final ChessMove? bestReply;

  const _ScoredMove({
    required this.move,
    required this.score,
    required this.bestReply,
  });
}

int _scorePlayedMove(
  NativeEngine engine,
  ChessBoard childBoard,
  int referenceMs,
  int referenceDepth,
) {
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
    timeLimitMs: referenceMs,
    maxDepth: math.max(1, referenceDepth - 1),
    skillLevel: 4,
  );
  return -reply.score;
}

String _moveLabel(ChessMove? move) {
  if (move == null) return '(none)';
  final piece = switch (move.piece.type) {
    PieceType.pawn => '',
    PieceType.knight => 'N',
    PieceType.bishop => 'B',
    PieceType.rook => 'R',
    PieceType.queen => 'Q',
    PieceType.king => 'K',
  };
  final capture = move.isCapture ? 'x' : '-';
  final promotion = move.isPromotion ? '=${move.promotionPiece}' : '';
  return '$piece${move.from.algebraic}$capture${move.to.algebraic}$promotion';
}

String _cp(int score) {
  if (isMateScore(score)) {
    final mateIn = (mateScore - score.abs() + 1) ~/ 2;
    return score > 0 ? 'M$mateIn' : '-M$mateIn';
  }
  final cp = score / 100.0;
  return '${cp >= 0 ? '+' : ''}${cp.toStringAsFixed(2)}';
}

String? _readArg(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      final value = arg.substring(prefix.length);
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

int _readIntArg(List<String> args, String name, int fallback) {
  final value = _readArg(args, name);
  return value == null ? fallback : int.tryParse(value) ?? fallback;
}
