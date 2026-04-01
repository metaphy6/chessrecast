import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/evaluation.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/mods_enum.dart';

class _AnalyzedPly {
  final int ply;
  final String fen;
  final List<String> replayPrefix;
  final PieceColor sideToMove;
  final ChessMove playedMove;
  final ChessMove? referenceMove;
  final int baselineScore;
  final int referenceScore;
  final int referenceMoveScore;
  final int playedScore;
  final int delta;

  const _AnalyzedPly({
    required this.ply,
    required this.fen,
    required this.replayPrefix,
    required this.sideToMove,
    required this.playedMove,
    required this.referenceMove,
    required this.baselineScore,
    required this.referenceScore,
    required this.referenceMoveScore,
    required this.playedScore,
    required this.delta,
  });
}

void main(List<String> args) {
  print(runKingsBattleAudit(args));
}

String runKingsBattleAudit(List<String> args) {
  final options = _Options.fromArgs(args);
  final engine = NativeEngine();
  final orchestrator = Orchestrator();

  var board = options.startingFen == null
      ? ChessBoard.initial(gameType: ModsEnum.kingsBattle)
      : ChessBoard.fromFEN(
          options.startingFen!,
          gameType: ModsEnum.kingsBattle,
        );
  final analyzed = <_AnalyzedPly>[];
  final lines = <String>[];

  lines.add(
    'Kings Battle audit: baseline d${options.baselineDepth}/${options.baselineMs}ms '
    's${options.baselineSkill} vs reference '
    'd${options.referenceDepth}/${options.referenceMs}ms '
    's${options.referenceSkill}, '
    'max plies ${options.maxPlies}',
  );

  if (options.startingFen != null) {
    lines.add('Starting FEN: ${options.startingFen}');
  }
  if (options.openingMoves.isNotEmpty) {
    lines.add('Opening prefix: ${options.openingMoves.join(', ')}');
    for (final notation in options.openingMoves) {
      final move = orchestrator.parseAlgebraicNotation(board, notation);
      if (move == null) {
        throw ArgumentError('Illegal Kings Battle opening move: $notation');
      }
      board = orchestrator.executeMove(board, move);
    }
  }
  lines.add(
    "Exact King's Battle reproduction requires replay history once unlock/bonus-turn state matters, not just FEN.",
  );

  final replayPrefix = <String>[...options.openingMoves];

  for (var ply = 1; ply <= options.maxPlies; ply++) {
    if (board.gameStatus.isGameOver) {
      break;
    }

    final fen = board.toFEN();
    final side = board.currentPlayer;

    engine.resetState();
    final baseline = engine.findBestMoveSync(
      board,
      timeLimitMs: options.baselineMs,
      maxDepth: options.baselineDepth,
      skillLevel: options.baselineSkill,
    );

    final playedMove = baseline.bestMove;
    if (playedMove == null) {
      lines.add('ply $ply: no legal move, status=${board.gameStatus.name}');
      break;
    }

    engine.resetState();
    final reference = engine.findBestMoveSync(
      board,
      timeLimitMs: options.referenceMs,
      maxDepth: options.referenceDepth,
      skillLevel: options.referenceSkill,
    );

    final nextBoard = _executeAuditedMove(
      orchestrator,
      board,
      playedMove,
      role: 'baseline',
      ply: ply,
      fen: fen,
      replayPrefix: replayPrefix,
    );
    final playedScore = _scorePlayedMove(
      engine,
      mover: side,
      childBoard: nextBoard,
      referenceMs: options.referenceMs,
      referenceDepth: options.referenceDepth,
      referenceSkill: options.referenceSkill,
    );

    final referenceMove = reference.bestMove;
    final referenceMoveScore = referenceMove == null
        ? reference.score
        : referenceMove == playedMove
        ? playedScore
        : _scorePlayedMove(
            engine,
            mover: side,
            childBoard: _executeAuditedMove(
              orchestrator,
              board,
              referenceMove,
              role: 'reference',
              ply: ply,
              fen: fen,
              replayPrefix: replayPrefix,
            ),
            referenceMs: options.referenceMs,
            referenceDepth: options.referenceDepth,
            referenceSkill: options.referenceSkill,
          );

    final delta = referenceMoveScore - playedScore;
    final analyzedPly = _AnalyzedPly(
      ply: ply,
      fen: fen,
      replayPrefix: List<String>.unmodifiable(replayPrefix),
      sideToMove: side,
      playedMove: playedMove,
      referenceMove: referenceMove,
      baselineScore: baseline.score,
      referenceScore: reference.score,
      referenceMoveScore: referenceMoveScore,
      playedScore: playedScore,
      delta: delta,
    );
    analyzed.add(analyzedPly);

    lines.add(
      'ply ${analyzedPly.ply.toString().padLeft(2)} '
      '${side.name[0].toUpperCase()} '
      'played=${_moveLabel(analyzedPly.playedMove)} '
      'ref=${_moveLabel(analyzedPly.referenceMove)} '
      'base=${_cp(analyzedPly.baselineScore)} '
      'ref=${_cp(analyzedPly.referenceScore)} '
      'ref-move=${_cp(analyzedPly.referenceMoveScore)} '
      'played=${_cp(analyzedPly.playedScore)} '
      'delta=${_cp(analyzedPly.delta)}',
    );

    board = nextBoard;
    replayPrefix.add(_coordinateLabel(playedMove));
  }

  lines.add('');
  lines.add(
    'Final status: ${board.gameStatus.name} after ${analyzed.length} plies',
  );
  lines.add('Final FEN: ${board.toFEN()}');
  lines.add('');

  final worst = [...analyzed]..sort((a, b) => b.delta.compareTo(a.delta));
  final limit = math.min(options.topCount, worst.length);
  if (limit == 0) {
    lines.add('No analyzed plies.');
    return lines.join('\n');
  }

  lines.add('Worst $limit misses:');
  for (var index = 0; index < limit; index++) {
    final item = worst[index];
    lines.add(
      '${index + 1}. ply ${item.ply} ${item.sideToMove.name} '
      'delta=${_cp(item.delta)} '
      'played=${_moveLabel(item.playedMove)} '
      'ref=${_moveLabel(item.referenceMove)}',
    );
    lines.add('   FEN: ${item.fen}');
    lines.add(
      '   Replay: '
      '${item.replayPrefix.isEmpty ? '(starting position)' : item.replayPrefix.join(',')}',
    );
    lines.add(
      '   baseline=${_cp(item.baselineScore)} '
      'reference=${_cp(item.referenceScore)} '
      'reference-move=${_cp(item.referenceMoveScore)} '
      'played=${_cp(item.playedScore)}',
    );
  }

  return lines.join('\n');
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

ChessBoard _executeAuditedMove(
  Orchestrator orchestrator,
  ChessBoard board,
  ChessMove move, {
  required String role,
  required int ply,
  required String fen,
  required List<String> replayPrefix,
}) {
  try {
    return orchestrator.executeMove(board, move);
  } catch (error) {
    final replay = replayPrefix.isEmpty
        ? '(starting position)'
        : replayPrefix.join(',');
    throw StateError(
      'Illegal native $role move ${_moveLabel(move)} at ply $ply '
      'from FEN "$fen" after replay "$replay": $error',
    );
  }
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

String _coordinateLabel(ChessMove move) {
  final promotion = move.isPromotion
      ? move.promotionPiece?.toLowerCase() ?? ''
      : '';
  return '${move.from.algebraic}${move.to.algebraic}$promotion';
}

String _cp(int score) {
  if (isMateScore(score)) {
    final mateIn = (mateScore - score.abs() + 1) ~/ 2;
    return score > 0 ? 'M$mateIn' : '-M$mateIn';
  }
  final cp = score / 100.0;
  return '${cp >= 0 ? '+' : ''}${cp.toStringAsFixed(2)}';
}

class _Options {
  final int baselineDepth;
  final int baselineMs;
  final int baselineSkill;
  final int referenceDepth;
  final int referenceMs;
  final int referenceSkill;
  final int maxPlies;
  final int topCount;
  final String? startingFen;
  final List<String> openingMoves;

  const _Options({
    required this.baselineDepth,
    required this.baselineMs,
    required this.baselineSkill,
    required this.referenceDepth,
    required this.referenceMs,
    required this.referenceSkill,
    required this.maxPlies,
    required this.topCount,
    required this.startingFen,
    required this.openingMoves,
  });

  factory _Options.fromArgs(List<String> args) {
    int readInt(String name, int fallback) {
      final prefix = '--$name=';
      for (final arg in args) {
        if (arg.startsWith(prefix)) {
          return int.tryParse(arg.substring(prefix.length)) ?? fallback;
        }
      }
      return fallback;
    }

    String? readString(String name) {
      final prefix = '--$name=';
      for (final arg in args) {
        if (arg.startsWith(prefix)) {
          final value = arg.substring(prefix.length);
          return value.isEmpty ? null : value;
        }
      }
      return null;
    }

    final openingArg = readString('moves') ?? '';
    final openingMoves = openingArg.isEmpty
        ? const <String>[]
        : openingArg.split(',').where((s) => s.isNotEmpty).toList();

    return _Options(
      baselineDepth: readInt('baseline-depth', 4),
      baselineMs: readInt('baseline-ms', 120),
      baselineSkill: readInt('baseline-skill', 4),
      referenceDepth: readInt('reference-depth', 6),
      referenceMs: readInt('reference-ms', 500),
      referenceSkill: readInt('reference-skill', 4),
      maxPlies: readInt('max-plies', 24),
      topCount: readInt('top-count', 8),
      startingFen: readString('fen'),
      openingMoves: openingMoves,
    );
  }
}
