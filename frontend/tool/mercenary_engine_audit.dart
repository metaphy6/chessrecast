import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';

class _AnalyzedPly {
  final int ply;
  final String fen;
  final PieceColor sideToMove;
  final ChessMove playedMove;
  final ChessMove? referenceMove;
  final int baselineScore;
  final int referenceScore;
  final int playedScore;
  final int delta;

  const _AnalyzedPly({
    required this.ply,
    required this.fen,
    required this.sideToMove,
    required this.playedMove,
    required this.referenceMove,
    required this.baselineScore,
    required this.referenceScore,
    required this.playedScore,
    required this.delta,
  });
}

void main(List<String> args) {
  print(runMercenaryAudit(args));
}

String runMercenaryAudit(List<String> args) {
  final options = _Options.fromArgs(args);
  final engine = NativeEngine();
  final orchestrator = Orchestrator();

  var board = options.startingFen == null
      ? ChessBoard.initial(gameType: ModsEnum.mercenary)
      : ChessBoard.fromFEN(options.startingFen!, gameType: ModsEnum.mercenary);
  final analyzed = <_AnalyzedPly>[];
  final lines = <String>[];

  lines.add(
    'Mercenary audit: baseline d${options.baselineDepth}/${options.baselineMs}ms '
    's${options.baselineSkill} vs reference d${options.referenceDepth}/${options.referenceMs}ms '
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
        throw ArgumentError('Illegal Mercenary opening move: $notation');
      }
      board = orchestrator.executeMove(board, move);
    }
  }

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

    final nextBoard = orchestrator.executeMove(board, playedMove);
    final playedScore = _scorePlayedMove(
      engine,
      nextBoard,
      options.referenceMs,
      options.referenceDepth,
      options.referenceSkill,
    );

    final delta = reference.score - playedScore;
    final analyzedPly = _AnalyzedPly(
      ply: ply,
      fen: fen,
      sideToMove: side,
      playedMove: playedMove,
      referenceMove: reference.bestMove,
      baselineScore: baseline.score,
      referenceScore: reference.score,
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
      'played=${_cp(analyzedPly.playedScore)} '
      'delta=${_cp(analyzedPly.delta)}',
    );

    board = nextBoard;
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
      '   baseline=${_cp(item.baselineScore)} '
      'reference=${_cp(item.referenceScore)} '
      'played=${_cp(item.playedScore)}',
    );
  }

  return lines.join('\n');
}

int _scorePlayedMove(
  NativeEngine engine,
  ChessBoard childBoard,
  int referenceMs,
  int referenceDepth,
  int referenceSkill,
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
    skillLevel: referenceSkill,
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

    final moves = (readString('moves') ?? '')
        .split(',')
        .map((move) => move.trim())
        .where((move) => move.isNotEmpty)
        .toList(growable: false);

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
      openingMoves: moves,
    );
  }
}
