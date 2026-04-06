import 'dart:io';
import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'manual Friendly Fire root probe',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runFriendlyFireRootProbe(
        fen: env('FRIENDLY_FIRE_ROOT_PROBE_FEN', ''),
        movesArg: env('FRIENDLY_FIRE_ROOT_PROBE_MOVES', ''),
        depth: int.tryParse(env('FRIENDLY_FIRE_ROOT_PROBE_DEPTH', '4')) ?? 4,
        timeMs:
            int.tryParse(env('FRIENDLY_FIRE_ROOT_PROBE_TIME_MS', '120')) ?? 120,
        skillLevel:
            int.tryParse(env('FRIENDLY_FIRE_ROOT_PROBE_SKILL', '4')) ?? 4,
        candidateArg: env('FRIENDLY_FIRE_ROOT_PROBE_CANDIDATES', ''),
      );

      final reportFile = File(
        env(
          'FRIENDLY_FIRE_ROOT_PROBE_REPORT_PATH',
          '/tmp/friendly_fire_root_probe_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Root best:'));
    },
    skip:
        'Manual Friendly Fire root probe; run with --run-skipped when diagnosing a specific replay position.',
  );
}

String runFriendlyFireRootProbe({
  required String fen,
  required String movesArg,
  required int depth,
  required int timeMs,
  required int skillLevel,
  required String candidateArg,
}) {
  final replayMoves = movesArg.isEmpty
      ? const <String>[]
      : movesArg.split(',').where((s) => s.isNotEmpty).toList();
  if (fen.isEmpty && replayMoves.isEmpty) {
    throw ArgumentError('Provide Friendly Fire replay moves and/or a FEN');
  }

  final candidates = candidateArg.isEmpty
      ? const <String>[]
      : candidateArg.split(',').where((s) => s.isNotEmpty).toList();
  final orchestrator = Orchestrator();
  final board = _buildBoard(orchestrator, fen, replayMoves);
  final engine = NativeEngine();
  final lines = <String>[
    'Friendly Fire root probe: d$depth/${timeMs}ms',
    if (replayMoves.isNotEmpty) 'Replay prefix: ${replayMoves.join(', ')}',
    'Position FEN: ${board.toFEN()}',
    'Side to move: ${board.currentPlayer.name}',
  ];

  engine.resetState();
  final root = engine.findBestMoveSync(
    board,
    timeLimitMs: timeMs,
    maxDepth: depth,
    skillLevel: skillLevel,
  );
  lines.add('Root best: ${_moveLabel(root.bestMove)} score=${_cp(root.score)}');

  if (candidates.isNotEmpty) {
    lines.add('');
    lines.add('Requested candidates:');
    for (final notation in candidates) {
      final move = _parseCoordinateMove(orchestrator, board, notation);
      if (move == null) {
        lines.add('- $notation: not legal');
        continue;
      }
      final score = _scorePlayedMove(
        engine,
        mover: board.currentPlayer,
        childBoard: orchestrator.executeMove(board, move),
        referenceMs: timeMs,
        referenceDepth: depth,
        referenceSkill: skillLevel,
      );
      lines.add('- $notation => ${_moveLabel(move)} score=${_cp(score)}');
    }
  }

  return lines.join('\n');
}

ChessBoard _buildBoard(
  Orchestrator orchestrator,
  String fen,
  List<String> replayMoves,
) {
  var board = fen.isEmpty
      ? ChessBoard.initial(gameType: ModsEnum.friendlyFire)
      : ChessBoard.fromFEN(fen, gameType: ModsEnum.friendlyFire);

  for (final notation in replayMoves) {
    final move = _parseCoordinateMove(orchestrator, board, notation);
    if (move == null) {
      throw ArgumentError('Illegal Friendly Fire replay move: $notation');
    }
    board = orchestrator.executeMove(board, move);
  }

  return board;
}

int _scorePlayedMove(
  NativeEngine engine, {
  required PieceColor mover,
  required ChessBoard childBoard,
  required int referenceMs,
  required int referenceDepth,
  required int referenceSkill,
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
    timeLimitMs: referenceMs,
    maxDepth: math.max(1, referenceDepth - 1),
    skillLevel: referenceSkill,
  );
  return childBoard.currentPlayer == mover ? reply.score : -reply.score;
}

ChessMove? _parseCoordinateMove(
  Orchestrator orchestrator,
  ChessBoard board,
  String notation,
) {
  if (notation.length < 4) {
    return null;
  }

  try {
    final from = Position.fromAlgebraic(notation.substring(0, 2));
    final to = Position.fromAlgebraic(notation.substring(2, 4));
    final promotion = notation.length >= 5
        ? notation.substring(4, 5).toUpperCase()
        : null;

    for (final move in orchestrator.getAllValidMoves(board)) {
      if (move.from != from || move.to != to) {
        continue;
      }
      if (promotion != null && move.promotionPiece != promotion) {
        continue;
      }
      if (promotion == null && move.isPromotion) {
        continue;
      }
      return move;
    }
  } catch (_) {
    return null;
  }

  return null;
}

String _moveLabel(ChessMove? move) {
  if (move == null) {
    return '(none)';
  }
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
