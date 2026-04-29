// frontend/tool/kpi_dashboard.dart
//
// One-page KPI dashboard the agent posts at the start of every session.
// Reads agent/baselines/<mod>.json plus the most recent
// agent/reports/<mod>/*.txt for each mod and prints a markdown table:
// metric, baseline, current, delta, status.
//
// Usage (from repo root or frontend/):
//   dart run frontend/tool/kpi_dashboard.dart
//   dart run frontend/tool/kpi_dashboard.dart --mod heir
//
// Status legend:
//   ok       — within ±5% of baseline
//   warn     — regressed 5..10%
//   bad      — regressed > 10% (file a queue entry)
//   stale    — no recent report
//   missing  — no baseline yet
//
// This tool is read-only.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const mods = [
  'heir',
  'friendly_fire',
  'kings_battle',
  'mercenary',
  'save_the_queen',
  'succession',
  'truce',
];

const watchedKpis = [
  'avgWorstMiss_cp',
  'maxWorstMiss_cp',
  'earlyKingMoves',
  'castlingRightLosses',
  'castledByPly_avg',
  'kingExposureIndex_avg',
  'blundersGte200cp',
  'blundersGte300cp',
  'ruleViolations',
  'engineCrashes',
];

void main(List<String> args) {
  final modFilter = _argValue(args, '--mod');
  final repoRoot = _findRepoRoot();
  if (repoRoot == null) {
    stderr.writeln(
      'kpi_dashboard: could not locate repo root (no agent/ dir).',
    );
    exit(2);
  }

  final selected = modFilter == null ? mods : [modFilter];
  for (final mod in selected) {
    _printModSection(repoRoot, mod);
  }
}

String? _argValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return null;
}

String? _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/agent').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

void _printModSection(String root, String mod) {
  final baselinePath = '$root/agent/baselines/$mod.json';
  final reportDir = Directory('$root/agent/reports/$mod');

  print('## $mod');
  if (!File(baselinePath).existsSync()) {
    print('- baseline: **missing** — run `/improve-mod $mod` to generate.\n');
    return;
  }
  Map<String, dynamic> baseline;
  try {
    baseline =
        jsonDecode(File(baselinePath).readAsStringSync())
            as Map<String, dynamic>;
  } catch (e) {
    print('- baseline: **unreadable** ($e)\n');
    return;
  }
  final baseKpi =
      (baseline['kpi'] as Map?)?.cast<String, dynamic>() ?? const {};
  final genAt = baseline['generated_at']?.toString() ?? '?';

  // Newest report file in agent/reports/<mod>/.
  File? latest;
  if (reportDir.existsSync()) {
    final reports =
        reportDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.txt'))
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );
    if (reports.isNotEmpty) latest = reports.first;
  }

  print('- baseline: $genAt');
  print('- latest report: ${latest?.path ?? "(none)"}');
  if (latest == null) {
    print('  status: **stale** — no audit report found.\n');
    return;
  }

  // Heuristically scan the report for KPI-like lines. The audit harness
  // emits lines like "avgWorstMiss_cp=42" or "avgWorstMiss_cp: 42".
  final body = latest.readAsStringSync();
  print('');
  print('| metric | baseline | current | delta | status |');
  print('| --- | --- | --- | --- | --- |');
  for (final k in watchedKpis) {
    final base = baseKpi[k];
    final cur = _scrapeMetric(body, k);
    final status = _statusFor(base, cur);
    final delta = _delta(base, cur);
    print('| $k | ${_fmt(base)} | ${_fmt(cur)} | $delta | $status |');
  }
  print('');
}

num? _scrapeMetric(String body, String key) {
  final re = RegExp(RegExp.escape(key) + r'\s*[:=]\s*([\-+]?\d+(?:\.\d+)?)');
  final m = re.firstMatch(body);
  if (m == null) return null;
  return num.tryParse(m.group(1)!);
}

String _fmt(Object? v) => v == null ? '—' : v.toString();

String _delta(Object? base, Object? cur) {
  if (base is num && cur is num) {
    final d = cur - base;
    final s = d > 0 ? '+$d' : '$d';
    return s;
  }
  return '—';
}

String _statusFor(Object? base, Object? cur) {
  if (base == null) return 'missing';
  if (cur == null) return 'stale';
  if (base is! num || cur is! num) return '—';
  if (base == 0) {
    return cur == 0 ? 'ok' : (cur.abs() <= 1 ? 'warn' : 'bad');
  }
  // "Lower is better" for every KPI in this list.
  final pct = ((cur - base) / base.abs()).abs();
  if (cur > base && pct > 0.10) return '**bad**';
  if (cur > base && pct > 0.05) return 'warn';
  return 'ok';
}
