/// Mercenary preset calibration tool.
///
/// Mirrors `truce_preset_calibration.dart` for the Mercenary variant.
/// Sweeps all engine levels against a high-quality reference search and
/// reports per-level average miss, max miss, and exact-match rate.
///
/// In Mercenary, pawns move one square in any of the 8 directions and
/// capture forward (like standard chess), making the opening richly tactical.
/// Calibration cases include both standard forward development and positions
/// where lateral pawn pressure matters.
///
/// Usage:
///   dart tool/mercenary_preset_calibration.dart [--suite=<smoke|regression|production>]
///     [--levels=<easy,medium,...>]
///     [--reference-depth=12] [--reference-ms=4000] [--reference-skill=4]
///     [--top-count=5]
library;

import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/engine.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/engine/score_utils.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';

// ---------------------------------------------------------------------------
// Calibration cases
// ---------------------------------------------------------------------------

const List<_CalibrationCase> _regressionCases = [
  _CalibrationCase(
    name: 'e3 e6 d3 d6 — symmetric center advance',
    replay: ['e2e3', 'e7e6', 'd2d3', 'd7d6'],
  ),
  _CalibrationCase(
    name: 'e3 e6 Nf3 Nf6 — early knight development',
    replay: ['e2e3', 'e7e6', 'g1f3', 'g8f6'],
  ),
  _CalibrationCase(
    name: 'd3 d6 c3 c6 Nc3 Nc6 — closed pawn structure',
    replay: ['d2d3', 'd7d6', 'c2c3', 'c7c6', 'b1c3', 'b8c6'],
  ),
  _CalibrationCase(
    name: 'e3 Nf6 Nc3 e6 d3 — central control',
    replay: ['e2e3', 'g8f6', 'b1c3', 'e7e6', 'd2d3'],
  ),
  _CalibrationCase(
    name: 'Nf3 Nf6 d3 d6 Nc3 — double-knight setup',
    replay: ['g1f3', 'g8f6', 'd2d3', 'd7d6', 'b1c3'],
  ),
  _CalibrationCase(
    name: 'e3 d6 d3 e6 Bb5+ — bishop check line',
    replay: ['e2e3', 'd7d6', 'd2d3', 'e7e6', 'f1b5'],
  ),
  _CalibrationCase(
    name: 'c3 c6 d3 d6 e3 e6 — triple pawn lock',
    replay: ['c2c3', 'c7c6', 'd2d3', 'd7d6', 'e2e3', 'e7e6'],
  ),
  _CalibrationCase(
    name: 'Nf3 d6 d3 Nc6 e3 — asymmetric structure',
    replay: ['g1f3', 'd7d6', 'd2d3', 'b8c6', 'e2e3'],
  ),
];

const List<_CalibrationCase> _clusterCases = [
  _CalibrationCase(
    name: 'e3 e6 Nc3 Nc6 d3 — knight pair early',
    replay: ['e2e3', 'e7e6', 'b1c3', 'b8c6', 'd2d3'],
  ),
  _CalibrationCase(
    name: 'd3 d6 Nf3 Nf6 Bg5 — pin probe',
    replay: ['d2d3', 'd7d6', 'g1f3', 'g8f6', 'c1g5'],
  ),
  _CalibrationCase(
    name: 'e3 Nc6 Bb5 e6 — bishop-pawn pressure',
    replay: ['e2e3', 'b8c6', 'f1b5', 'e7e6'],
  ),
  _CalibrationCase(
    name: 'Nc3 e6 e3 d6 Nf3 — kings-side unwind',
    replay: ['b1c3', 'e7e6', 'e2e3', 'd7d6', 'g1f3'],
  ),
  _CalibrationCase(
    name: 'd3 Nf6 c3 d6 Bg5 — lateral-pawn pressure pin',
    replay: ['d2d3', 'g8f6', 'c2c3', 'd7d6', 'c1g5'],
  ),
  _CalibrationCase(
    name: 'f3 e6 d3 d6 Nc3 — f-pawn Mercenary line',
    replay: ['f2f3', 'e7e6', 'd2d3', 'd7d6', 'b1c3'],
  ),
];

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

final RegExp _aggregateLine = RegExp(
  r'^([a-z]+): avg miss ([0-9]+\.[0-9]+) max ([0-9]+\.[0-9]+) exact ([0-9]+)/([0-9]+)$',
  multiLine: true,
);

void main(List<String> args) {
  print(runMercenaryPresetCalibration(args));
}

String runMercenaryPresetCalibration(List<String> args) {
  final options = _CalibrationOptions.fromArgs(args);
  final orchestrator = Orchestrator();
  final engine = NativeEngine();
  final lines = <String>[
    'Mercenary preset calibration (${options.suiteName}): ${options.cases.length} root positions, '
        'reference d${options.referenceDepth}/${options.referenceMs}ms '
        's${options.referenceSkill}',
  ];

  for (final level in options.levels) {
    final results = <_CalibrationResult>[];
    lines.add('');
    lines.add(
      '${level.name}: d${level.maxDepth}/${level.timeLimitMs}ms s${level.skillLevel}',
    );

    for (final testCase in options.cases) {
      final board = _boardFromReplay(orchestrator, testCase.replay);

      engine.resetState();
      final baseline = engine.findBestMoveSync(
        board,
        timeLimitMs: level.timeLimitMs,
        maxDepth: level.maxDepth,
        skillLevel: level.skillLevel,
      );

      final playedMove = baseline.bestMove;
      if (playedMove == null) {
        results.add(
          _CalibrationResult(
            name: testCase.name,
            replay: testCase.replay,
            delta: 0,
            exactMatch: false,
            playedMove: '(none)',
            referenceMove: '(none)',
          ),
        );
        continue;
      }

      engine.resetState();
      final reference = engine.findBestMoveSync(
        board,
        timeLimitMs: options.referenceMs,
        maxDepth: options.referenceDepth,
        skillLevel: options.referenceSkill,
      );

      final playedScore = _scoreMove(
        engine,
        orchestrator.executeMove(board, playedMove),
        options.referenceMs,
        options.referenceDepth,
        options.referenceSkill,
      );

      final referenceMove = reference.bestMove;
      final referenceMoveScore = referenceMove == null
          ? reference.score
          : referenceMove == playedMove
          ? playedScore
          : _scoreMove(
              engine,
              orchestrator.executeMove(board, referenceMove),
              options.referenceMs,
              options.referenceDepth,
              options.referenceSkill,
            );

      final delta = referenceMoveScore - playedScore;
      results.add(
        _CalibrationResult(
          name: testCase.name,
          replay: testCase.replay,
          delta: delta,
          exactMatch:
              _coordinateLabel(playedMove) == _coordinateLabel(referenceMove),
          playedMove: _moveLabel(playedMove),
          referenceMove: _moveLabel(referenceMove),
        ),
      );
    }

    final average = results.isEmpty
        ? 0.0
        : results
                  .map((result) => result.delta)
                  .reduce((left, right) => left + right) /
              results.length /
              100.0;
    final maxDelta = results.isEmpty
        ? 0.0
        : results.map((result) => result.delta).reduce(math.max) / 100.0;
    final exact = results.where((result) => result.exactMatch).length;
    lines.add(
      '${level.name}: avg miss ${average.toStringAsFixed(2)} '
      'max ${maxDelta.toStringAsFixed(2)} '
      'exact $exact/${results.length}',
    );

    final worst = [...results]..sort((a, b) => b.delta.compareTo(a.delta));
    final worstCount = math.min(options.topCount, worst.length);
    if (worstCount == 0) continue;

    lines.add('Worst $worstCount:');
    for (var index = 0; index < worstCount; index++) {
      final item = worst[index];
      lines.add(
        '${index + 1}. ${item.name} '
        'delta=${_cp(item.delta)} '
        'played=${item.playedMove} '
        'ref=${item.referenceMove}',
      );
      lines.add('   Replay: ${item.replay.join(',')}');
    }
  }

  lines.add('');
  lines.add('Summary:');
  final aggregateLines = lines
      .where((line) => _aggregateLine.hasMatch(line))
      .toList(growable: false);
  lines.addAll(aggregateLines);
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

class _CalibrationCase {
  final String name;
  final List<String> replay;

  const _CalibrationCase({required this.name, required this.replay});
}

class _CalibrationResult {
  final String name;
  final List<String> replay;
  final int delta;
  final bool exactMatch;
  final String playedMove;
  final String referenceMove;

  const _CalibrationResult({
    required this.name,
    required this.replay,
    required this.delta,
    required this.exactMatch,
    required this.playedMove,
    required this.referenceMove,
  });
}

class _CalibrationOptions {
  final String suiteName;
  final List<_CalibrationCase> cases;
  final List<EngineLevel> levels;
  final int referenceDepth;
  final int referenceMs;
  final int referenceSkill;
  final int topCount;

  const _CalibrationOptions({
    required this.suiteName,
    required this.cases,
    required this.levels,
    required this.referenceDepth,
    required this.referenceMs,
    required this.referenceSkill,
    required this.topCount,
  });

  factory _CalibrationOptions.fromArgs(List<String> args) {
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

    final suiteName = readString('suite') ?? 'production';
    final levelsArg = readString('levels');

    return _CalibrationOptions(
      suiteName: suiteName,
      cases: _buildCases(suiteName),
      levels: _parseLevels(levelsArg),
      referenceDepth: readInt('reference-depth', 12),
      referenceMs: readInt('reference-ms', 4000),
      referenceSkill: readInt('reference-skill', 4),
      topCount: readInt('top-count', 5),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<_CalibrationCase> _buildCases(String suiteName) {
  switch (suiteName.toLowerCase()) {
    case 'smoke':
      return [
        _regressionCases[0],
        _regressionCases[2],
        _regressionCases[4],
        _clusterCases[0],
        _clusterCases[3],
      ];
    case 'regression':
      return _regressionCases;
    case 'production':
    case 'offline':
      return [..._regressionCases, ..._clusterCases];
    default:
      throw ArgumentError(
        'Unknown Mercenary preset calibration suite: $suiteName',
      );
  }
}

List<EngineLevel> _parseLevels(String? levelsArg) {
  if (levelsArg == null || levelsArg.isEmpty) {
    return EngineLevel.values;
  }

  return levelsArg
      .split(',')
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .map((name) {
        for (final level in EngineLevel.values) {
          if (level.name == name) {
            return level;
          }
        }
        throw ArgumentError('Unknown EngineLevel: $name');
      })
      .toList(growable: false);
}

ChessBoard _boardFromReplay(Orchestrator orchestrator, List<String> replay) {
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

int _scoreMove(
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

String _coordinateLabel(ChessMove? move) {
  if (move == null) return '(none)';
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
