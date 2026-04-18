import 'dart:math' as math;

import 'audit_kpi.dart';
import 'friendly_fire_engine_audit.dart';

const List<String> _defaultWhiteOpenings = [
  'e2e4',
  'd2d4',
  'f2f4',
  'c2c4',
  'b2b4',
  'g2g4',
  'e2e3',
  'd2d3',
  'f2f3',
  'c2c3',
];

const List<String> _defaultBlackReplies = [
  'e7e5',
  'd7d5',
  'f7f5',
  'c7c5',
  'b7b5',
];

final RegExp _deltaLine = RegExp(
  r'^1\. ply (\d+) (\w+) delta=(-?M\d+|[+-]?\d+\.\d+) played=(.+) ref=(.+)$',
  multiLine: true,
);
final RegExp _fenLine = RegExp(r'^\s*FEN: (.+)$', multiLine: true);
final RegExp _replayLine = RegExp(r'^\s*Replay: (.+)$', multiLine: true);
final RegExp _statusLine = RegExp(r'^Final status: (.+)$', multiLine: true);

void main(List<String> args) {
  print(runFriendlyFireAuditBatch(args));
}

String runFriendlyFireAuditBatch(List<String> args) {
  final options = _BatchOptions.fromArgs(args);
  final summaries = <_BatchSummary>[];
  final lines = <String>[
    'Friendly Fire batch audit: ${options.openings.length} openings, '
        'baseline d${options.baselineDepth}/${options.baselineMs}ms '
        's${options.baselineSkill} vs reference '
        'd${options.referenceDepth}/${options.referenceMs}ms '
        's${options.referenceSkill}, '
        'max plies ${options.maxPlies}',
  ];

  for (var index = 0; index < options.openings.length; index++) {
    final opening = options.openings[index];
    final report = runFriendlyFireAudit([
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
    final openings = openingsArg == null
        ? _buildDefaultOpenings()
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

    return _BatchSummary(
      game: game,
      opening: opening,
      finalStatus: statusMatch?.group(1) ?? 'unknown',
      delta: _parseDeltaValue(deltaMatch.group(3)!),
      playedMove: deltaMatch.group(4)!,
      referenceMove: deltaMatch.group(5)!,
      fen: fenMatch?.group(1) ?? '(missing FEN)',
      replay: replayMatch?.group(1) ?? '(missing replay)',
      kpi: AuditKpiSnapshot.fromReport(report),
    );
  }
}

List<String> _buildDefaultOpenings() {
  final openings = <String>[];
  for (final white in _defaultWhiteOpenings) {
    for (final black in _defaultBlackReplies) {
      openings.add('$white,$black');
    }
  }
  return openings;
}

String _cp(double score) {
  final sign = score >= 0 ? '+' : '';
  return '$sign${score.toStringAsFixed(2)}';
}

double _parseDeltaValue(String value) {
  if (value.contains('M')) {
    return value.startsWith('-') ? -100.0 : 100.0;
  }
  return double.parse(value);
}
