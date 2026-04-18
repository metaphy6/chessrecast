import 'dart:math' as math;

import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';

import 'audit_kpi.dart';
import 'truce_engine_audit.dart';

const List<String> _defaultWhiteOpenings = [
  'e2e4',
  'd2d4',
  'c2c4',
  'g1f3',
  'b1c3',
  'g2g3',
  'b2b3',
  'e2e3',
  'd2d3',
  'f2f4',
];

const List<String> _expandedWhiteOpenings = [
  ..._defaultWhiteOpenings,
  'c2c3',
  'b2b4',
  'h2h3',
  'a2a3',
  'h2h4',
  'a2a4',
];

const List<String> _defaultBlackReplies = [
  'e7e5',
  'c7c5',
  'g8f6',
  'd7d5',
  'b8c6',
];

const List<String> _expandedBlackReplies = [
  ..._defaultBlackReplies,
  'e7e6',
  'c7c6',
  'b7b6',
];

const List<List<String>> _expandedTwoPlyWhitePlans = [
  ['e2e4', 'g1f3'],
  ['d2d4', 'g1f3'],
  ['c2c4', 'b1c3'],
  ['g1f3', 'd2d4'],
  ['b1c3', 'e2e4'],
  ['g2g3', 'f1g2'],
  ['b2b3', 'c1b2'],
  ['e2e3', 'f1d3'],
  ['d2d3', 'c1e3'],
  ['f2f4', 'b1c3'],
  ['c2c3', 'd2d4'],
  ['b2b4', 'c1b2'],
  ['h2h3', 'g1f3'],
  ['a2a3', 'b1c3'],
  ['h2h4', 'b1c3'],
  ['a2a4', 'b1c3'],
];

const List<List<String>> _expandedTwoPlyBlackPlans = [
  ['e7e5', 'g8f6'],
  ['e7e5', 'b8c6'],
  ['c7c5', 'g8f6'],
  ['c7c5', 'd7d5'],
  ['g8f6', 'd7d5'],
  ['d7d5', 'g8f6'],
  ['e7e6', 'g8f6'],
  ['c7c6', 'd7d5'],
  ['b7b6', 'c8b7'],
];

final RegExp _deltaLine = RegExp(
  r'^1\. ply (\d+) (\w+) delta=(-?M\d+|[+-]?\d+\.\d+) played=(.+) ref=(.+)$',
  multiLine: true,
);
final RegExp _fenLine = RegExp(r'^\s*FEN: (.+)$', multiLine: true);
final RegExp _replayLine = RegExp(r'^\s*Replay: (.+)$', multiLine: true);
final RegExp _statusLine = RegExp(r'^Final status: (.+)$', multiLine: true);

void main(List<String> args) {
  print(runTruceAuditBatch(args));
}

String runTruceAuditBatch(List<String> args) {
  final options = _BatchOptions.fromArgs(args);
  final summaries = <_BatchSummary>[];
  final lines = <String>[
    'Truce batch audit (${options.suiteName}): ${options.openings.length} openings, '
        'baseline d${options.baselineDepth}/${options.baselineMs}ms '
        's${options.baselineSkill} vs reference '
        'd${options.referenceDepth}/${options.referenceMs}ms '
        's${options.referenceSkill}, '
        'max plies ${options.maxPlies}',
  ];

  for (var index = 0; index < options.openings.length; index++) {
    final opening = options.openings[index];
    final report = runTruceAudit([
      '--baseline-depth=${options.baselineDepth}',
      '--baseline-ms=${options.baselineMs}',
      '--baseline-skill=${options.baselineSkill}',
      '--reference-depth=${options.referenceDepth}',
      '--reference-ms=${options.referenceMs}',
      '--reference-skill=${options.referenceSkill}',
      '--max-plies=${options.maxPlies}',
      '--top-count=${options.topCount}',
      '--moves=$opening',
    ]);

    final summary = _BatchSummary.fromReport(index + 1, opening, report);
    summaries.add(summary);

    lines.add('GAME ${summary.game} ${summary.opening}');
    lines.add(
      'status=${summary.finalStatus} '
      'worst=${_cp(summary.delta)} '
      'played=${summary.playedMove} '
      'ref=${summary.referenceMove}',
    );
    lines.add('FEN: ${summary.fen}');
    lines.add('Replay: ${summary.replay}');
  }

  final deltas = summaries
      .map((summary) => summary.delta)
      .toList(growable: false);
  final avgDelta = deltas.isEmpty
      ? 0.0
      : deltas.reduce((a, b) => a + b) / deltas.length;
  final maxDelta = deltas.isEmpty ? 0.0 : deltas.reduce(math.max);
  final overTwo = deltas.where((delta) => delta >= 2.0).length;
  final overThree = deltas.where((delta) => delta >= 3.0).length;

  lines.add('');
  lines.add(
    'Aggregate: avg worst miss ${avgDelta.toStringAsFixed(2)} '
    'max ${maxDelta.toStringAsFixed(2)} '
    '>=2.00 $overTwo/${deltas.length} '
    '>=3.00 $overThree/${deltas.length}',
  );
  lines.add(
    AuditKpiAggregate.fromSnapshots(
      summaries.map((s) => s.kpi).toList(),
    ).toSummaryLine(),
  );

  final worst = [...summaries]..sort((a, b) => b.delta.compareTo(a.delta));
  final worstCount = math.min(options.topCount, worst.length);
  if (worstCount > 0) {
    lines.add('');
    lines.add('Worst openings:');
    for (var index = 0; index < worstCount; index++) {
      final item = worst[index];
      lines.add(
        '${index + 1}. GAME ${item.game} ${item.opening} '
        'delta=${_cp(item.delta)} '
        'played=${item.playedMove} '
        'ref=${item.referenceMove}',
      );
      lines.add('   FEN: ${item.fen}');
      lines.add('   Replay: ${item.replay}');
    }
  }

  return lines.join('\n');
}

class _BatchOptions {
  final int baselineDepth;
  final int baselineMs;
  final int baselineSkill;
  final int referenceDepth;
  final int referenceMs;
  final int referenceSkill;
  final int maxPlies;
  final int topCount;
  final String suiteName;
  final List<String> openings;

  const _BatchOptions({
    required this.baselineDepth,
    required this.baselineMs,
    required this.baselineSkill,
    required this.referenceDepth,
    required this.referenceMs,
    required this.referenceSkill,
    required this.maxPlies,
    required this.topCount,
    required this.suiteName,
    required this.openings,
  });

  factory _BatchOptions.fromArgs(List<String> args) {
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

    final openingsArg = readString('openings');
    final suiteName = readString('suite') ?? 'default';
    final openings = openingsArg == null
        ? _buildOpeningsForSuite(suiteName)
        : openingsArg
              .split(';')
              .map((opening) => opening.trim())
              .where((opening) => opening.isNotEmpty)
              .toList(growable: false);

    return _BatchOptions(
      baselineDepth: readInt('baseline-depth', 4),
      baselineMs: readInt('baseline-ms', 120),
      baselineSkill: readInt('baseline-skill', 4),
      referenceDepth: readInt('reference-depth', 6),
      referenceMs: readInt('reference-ms', 500),
      referenceSkill: readInt('reference-skill', 4),
      maxPlies: readInt('max-plies', 24),
      topCount: readInt('top-count', 10),
      suiteName: openingsArg == null ? suiteName : 'custom',
      openings: openings,
    );
  }
}

class _BatchSummary {
  final int game;
  final String opening;
  final String finalStatus;
  final double delta;
  final String playedMove;
  final String referenceMove;
  final String fen;
  final String replay;
  final AuditKpiSnapshot kpi;

  const _BatchSummary({
    required this.game,
    required this.opening,
    required this.finalStatus,
    required this.delta,
    required this.playedMove,
    required this.referenceMove,
    required this.fen,
    required this.replay,
    required this.kpi,
  });

  factory _BatchSummary.fromReport(int game, String opening, String report) {
    final deltaMatch = _deltaLine.firstMatch(report);
    if (deltaMatch == null) {
      throw StateError('Missing worst-miss summary for opening $opening');
    }

    final fenMatch = _fenLine.firstMatch(report);
    final replayMatch = _replayLine.firstMatch(report);
    final statusMatch = _statusLine.firstMatch(report);

    final deltaRaw = deltaMatch.group(3)!;
    final delta = deltaRaw.contains('M')
        ? (deltaRaw.startsWith('-') ? -100.0 : 100.0)
        : double.parse(deltaRaw);

    return _BatchSummary(
      game: game,
      opening: opening,
      finalStatus: statusMatch?.group(1) ?? 'unknown',
      delta: delta,
      playedMove: deltaMatch.group(4)!,
      referenceMove: deltaMatch.group(5)!,
      fen: fenMatch?.group(1) ?? '(missing FEN)',
      replay: replayMatch?.group(1) ?? '(missing replay)',
      kpi: AuditKpiSnapshot.fromReport(report),
    );
  }
}

List<String> _buildDefaultOpenings() {
  return _buildOpeningMatrix(_defaultWhiteOpenings, _defaultBlackReplies);
}

List<String> _buildExpandedOpenings() {
  return _buildOpeningMatrix(_expandedWhiteOpenings, _expandedBlackReplies);
}

List<String> _buildExpandedTwoPlyOpenings() {
  final orchestrator = Orchestrator();
  final openings = <String>{};

  for (final whitePlan in _expandedTwoPlyWhitePlans) {
    for (final blackPlan in _expandedTwoPlyBlackPlans) {
      final replay = _interleavePlans(whitePlan, blackPlan);
      if (_isLegalReplay(orchestrator, replay)) {
        openings.add(replay.join(','));
      }
    }
  }

  final sorted = openings.toList(growable: false);
  sorted.sort();
  return sorted;
}

List<String> _buildOpeningsForSuite(String suiteName) {
  switch (suiteName.toLowerCase()) {
    case 'default':
      return _buildDefaultOpenings();
    case 'expanded':
    case 'broad':
      return _buildExpandedOpenings();
    case 'expanded-2ply':
    case 'expanded-two-ply':
    case 'broad-2ply':
    case 'deep':
      return _buildExpandedTwoPlyOpenings();
    default:
      throw ArgumentError('Unknown Truce batch suite: $suiteName');
  }
}

List<String> _buildOpeningMatrix(
  List<String> whiteOpenings,
  List<String> blackReplies,
) {
  final openings = <String>[];
  for (final white in whiteOpenings) {
    for (final black in blackReplies) {
      openings.add('$white,$black');
    }
  }
  return openings;
}

List<String> _interleavePlans(List<String> whitePlan, List<String> blackPlan) {
  final replay = <String>[];
  final maxLen = math.max(whitePlan.length, blackPlan.length);

  for (var ply = 0; ply < maxLen; ply++) {
    if (ply < whitePlan.length) replay.add(whitePlan[ply]);
    if (ply < blackPlan.length) replay.add(blackPlan[ply]);
  }

  return replay;
}

bool _isLegalReplay(Orchestrator orchestrator, List<String> replay) {
  var board = ChessBoard.initial(gameType: ModsEnum.truce);

  for (final notation in replay) {
    final move = orchestrator.parseAlgebraicNotation(board, notation);
    if (move == null) return false;
    board = orchestrator.executeMove(board, move);
  }

  return true;
}

String _cp(double score) {
  final sign = score >= 0 ? '+' : '';
  return '$sign${score.toStringAsFixed(2)}';
}
