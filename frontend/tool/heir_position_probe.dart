import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'position_probe_runner.dart';

void main(List<String> args) {
  print(runHeirPositionProbe(args));
}

String runHeirPositionProbe(List<String> args) {
  final fen = readProbeArg(args, 'fen');
  final movesArg = readProbeArg(args, 'moves') ?? '';
  final replayMoves = movesArg.isEmpty
      ? const <String>[]
      : movesArg.split(',').where((s) => s.isNotEmpty).toList();
  if ((fen == null || fen.isEmpty) && replayMoves.isEmpty) {
    throw ArgumentError('Provide --fen=<fen> and/or --moves=<uci,uci,...>');
  }

  final mode = (readProbeArg(args, 'mod') ?? 'heir').toLowerCase();
  final isSuccession = mode == 'succession';
  final modName = isSuccession ? 'Succession' : 'Heir';
  final gameType = isSuccession ? ModsEnum.succession : ModsEnum.heir;

  final depth = readProbeIntArg(args, 'depth', 6);
  final timeMs = readProbeIntArg(args, 'time-ms', 1200);
  final skillLevel = readProbeIntArg(args, 'skill', 4);
  final topCount = readProbeIntArg(args, 'top-count', 8);
  final candidateArg = readProbeArg(args, 'candidates') ?? '';
  final candidates = candidateArg.isEmpty
      ? const <String>[]
      : candidateArg.split(',').where((s) => s.isNotEmpty).toList();

  final engine = NativeEngine();
  final orchestrator = Orchestrator();
  final board = _buildBoard(
    orchestrator,
    fen,
    replayMoves,
    gameType: gameType,
    modName: modName,
  );
  final lines = <String>[];

  lines.add('$modName probe: d$depth/${timeMs}ms');
  if (fen != null && fen.isNotEmpty) {
    lines.add('Starting FEN: $fen');
  }
  if (replayMoves.isNotEmpty) {
    lines.add('Replay prefix: ${replayMoves.join(', ')}');
  }
  lines.add('Position FEN: ${board.toFEN()}');
  lines.add('Side to move: ${board.currentPlayer.name}');
  if (isSuccession) {
    lines.add(
      'Replay history can matter for Succession queen-loss and king-promotion race transitions.',
    );
  }
  lines.add('');

  final legalMoves = orchestrator.getAllValidMoves(board);
  final scored = <ProbeMove>[];
  for (final move in legalMoves) {
    final child = orchestrator.executeMove(board, move);
    final score = scoreProbeMove(
      engine,
      mover: board.currentPlayer,
      childBoard: child,
      referenceMs: timeMs,
      referenceDepth: depth,
      referenceSkill: skillLevel,
    );
    final bestReply = child.gameStatus.isGameOver
        ? null
        : (() {
            engine.resetState();
            return engine
                .findBestMoveSync(
                  child,
                  timeLimitMs: timeMs,
                  maxDepth: math.max(1, depth - 1),
                  skillLevel: skillLevel,
                )
                .bestMove;
          })();
    scored.add(ProbeMove(move: move, score: score, bestReply: bestReply));
  }

  scored.sort((a, b) => b.score.compareTo(a.score));

  lines.add('Top ${math.min(topCount, scored.length)} moves:');
  for (var index = 0; index < math.min(topCount, scored.length); index++) {
    final item = scored[index];
    lines.add(
      '${index + 1}. ${probeMoveLabel(item.move)} '
      'score=${probeCp(item.score)} '
      'reply=${probeMoveLabel(item.bestReply)}',
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
      ProbeMove? fromSweep;
      for (final scoredMove in scored) {
        if (sameProbeMove(scoredMove.move, move)) {
          fromSweep = scoredMove;
          break;
        }
      }
      final item =
          fromSweep ??
          analyzeProbeMove(
            engine,
            orchestrator,
            board,
            move,
            timeMs: timeMs,
            depth: depth,
            skillLevel: skillLevel,
          );
      lines.add(
        '- $notation => ${probeMoveLabel(item.move)} '
        'score=${probeCp(item.score)} '
        'reply=${probeMoveLabel(item.bestReply)}',
      );
    }
  }

  return lines.join('\n');
}

ChessBoard _buildBoard(
  Orchestrator orchestrator,
  String? fen,
  List<String> replayMoves, {
  required ModsEnum gameType,
  required String modName,
}) {
  var board = (fen == null || fen.isEmpty)
      ? ChessBoard.initial(gameType: gameType)
      : ChessBoard.fromFEN(fen, gameType: gameType);

  for (final notation in replayMoves) {
    final move = parseCoordinateMove(orchestrator, board, notation);
    if (move == null) {
      throw ArgumentError('Illegal $modName replay move: $notation');
    }
    board = orchestrator.executeMove(board, move);
  }

  return board;
}
