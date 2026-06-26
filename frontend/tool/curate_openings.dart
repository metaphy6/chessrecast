// ignore_for_file: avoid_print

import 'dart:io';

const kDefaultMods = [
  'heir',
  'friendly_fire',
  'kings_battle',
  'mercenary',
  'save_the_queen',
  'succession',
  'truce',
];

class CurateOptions {
  final String? mod;
  final int reportWindow;
  final int recurringReports;
  final double demoteWorstLt;
  final double promoteWorstGte;
  final String? outPath;

  const CurateOptions({
    this.mod,
    this.reportWindow = 3,
    this.recurringReports = 2,
    this.demoteWorstLt = 0.5,
    this.promoteWorstGte = 2.0,
    this.outPath,
  });
}

class WorstSample {
  final String reportPath;
  final int line;
  final double worst;

  const WorstSample({
    required this.reportPath,
    required this.line,
    required this.worst,
  });
}

class OpeningProposal {
  final String action;
  final String opening;
  final String reason;
  final List<WorstSample> evidence;

  const OpeningProposal({
    required this.action,
    required this.opening,
    required this.reason,
    required this.evidence,
  });
}

class ModPlan {
  final String mod;
  final String baselinePath;
  final List<String> reports;
  final List<OpeningProposal> proposals;
  final int openingsObserved;
  final String? warning;

  const ModPlan({
    required this.mod,
    required this.baselinePath,
    required this.reports,
    required this.proposals,
    required this.openingsObserved,
    this.warning,
  });
}

void main(List<String> args) {
  final options = _parseArgs(args);
  final root = _findRepoRoot();
  if (root == null) {
    stderr.writeln(
      'curate_openings: could not locate repo root (missing agent/).',
    );
    exit(2);
  }

  final mods = options.mod == null ? kDefaultMods : [options.mod!];
  final plans = <ModPlan>[];

  for (final mod in mods) {
    plans.add(buildModPlan(root, mod, options));
  }

  final yaml = renderYamlPlan(plans, options);
  if (options.outPath != null && options.outPath!.isNotEmpty) {
    final outFile = File(options.outPath!);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(yaml);
    print('Wrote YAML plan: ${outFile.path}');
  }

  print(yaml);
}

CurateOptions _parseArgs(List<String> args) {
  String? mod;
  int reportWindow = 3;
  int recurringReports = 2;
  double demoteWorstLt = 0.5;
  double promoteWorstGte = 2.0;
  String? outPath;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--mod' && i + 1 < args.length) {
      mod = args[++i];
    } else if (arg == '--reports' && i + 1 < args.length) {
      reportWindow = int.tryParse(args[++i]) ?? reportWindow;
    } else if (arg == '--recurring-reports' && i + 1 < args.length) {
      recurringReports = int.tryParse(args[++i]) ?? recurringReports;
    } else if (arg == '--demote-worst-lt' && i + 1 < args.length) {
      demoteWorstLt = double.tryParse(args[++i]) ?? demoteWorstLt;
    } else if (arg == '--promote-worst-gte' && i + 1 < args.length) {
      promoteWorstGte = double.tryParse(args[++i]) ?? promoteWorstGte;
    } else if (arg == '--out' && i + 1 < args.length) {
      outPath = args[++i];
    }
  }

  return CurateOptions(
    mod: mod,
    reportWindow: reportWindow < 1 ? 1 : reportWindow,
    recurringReports: recurringReports < 1 ? 1 : recurringReports,
    demoteWorstLt: demoteWorstLt,
    promoteWorstGte: promoteWorstGte,
    outPath: outPath,
  );
}

String? _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (Directory('${dir.path}/agent').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

ModPlan buildModPlan(String root, String mod, CurateOptions options) {
  final baselinePath = '$root/bots/baselines/$mod.json';
  final reportDir = Directory('$root/bots/reports/$mod');

  if (!File(baselinePath).existsSync()) {
    return ModPlan(
      mod: mod,
      baselinePath: _relPath(root, baselinePath),
      reports: const [],
      proposals: const [],
      openingsObserved: 0,
      warning: 'baseline_missing',
    );
  }

  final reports = <File>[];
  if (reportDir.existsSync()) {
    reports.addAll(
      reportDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.txt'),
      ),
    );
    reports.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
  }

  if (reports.isEmpty) {
    return ModPlan(
      mod: mod,
      baselinePath: _relPath(root, baselinePath),
      reports: const [],
      proposals: const [],
      openingsObserved: 0,
      warning: 'reports_missing',
    );
  }

  final selected = reports.take(options.reportWindow).toList();
  final selectedPaths = selected.map((f) => _relPath(root, f.path)).toList();

  final byOpening = <String, List<WorstSample>>{};
  for (final report in selected) {
    final parsed = parseReportWorstSamples(
      report.path,
      reportPathOverride: _relPath(root, report.path),
    );
    for (final entry in parsed.entries) {
      byOpening
          .putIfAbsent(entry.key, () => <WorstSample>[])
          .addAll(entry.value);
    }
  }

  final proposals = <OpeningProposal>[];
  byOpening.forEach((opening, samples) {
    final reportSet = samples.map((s) => s.reportPath).toSet();
    final blunderSamples = samples
        .where((s) => s.worst >= options.promoteWorstGte)
        .toList();
    final blunderReports = blunderSamples.map((s) => s.reportPath).toSet();

    final seenAllReports = reportSet.length >= selected.length;
    final stableEasy =
        selected.length >= 3 &&
        seenAllReports &&
        blunderSamples.isEmpty &&
        samples.every((s) => s.worst < options.demoteWorstLt);
    final recurringBlunder = blunderReports.length >= options.recurringReports;

    if (recurringBlunder) {
      blunderSamples.sort((a, b) => b.worst.compareTo(a.worst));
      proposals.add(
        OpeningProposal(
          action: 'promote_to_stress',
          opening: opening,
          reason:
              'worst_miss >= ${options.promoteWorstGte.toStringAsFixed(2)} in '
              '${blunderReports.length}/${selected.length} reports',
          evidence: blunderSamples.take(3).toList(),
        ),
      );
      return;
    }

    if (stableEasy) {
      final sorted = [...samples]..sort((a, b) => a.worst.compareTo(b.worst));
      proposals.add(
        OpeningProposal(
          action: 'demote_to_discovery',
          opening: opening,
          reason:
              'worst_miss < ${options.demoteWorstLt.toStringAsFixed(2)} '
              'with 0 blunders across ${selected.length}/${selected.length} reports',
          evidence: sorted.take(3).toList(),
        ),
      );
    }
  });

  proposals.sort((a, b) {
    if (a.action != b.action) {
      return a.action == 'promote_to_stress' ? -1 : 1;
    }
    final aw = a.evidence.isEmpty ? 0.0 : a.evidence.first.worst;
    final bw = b.evidence.isEmpty ? 0.0 : b.evidence.first.worst;
    return bw.compareTo(aw);
  });

  String? warning;
  if (selected.length < options.reportWindow) {
    warning = 'insufficient_report_history';
  }

  return ModPlan(
    mod: mod,
    baselinePath: _relPath(root, baselinePath),
    reports: selectedPaths,
    proposals: proposals,
    openingsObserved: byOpening.length,
    warning: warning,
  );
}

Map<String, List<WorstSample>> parseReportWorstSamples(
  String reportPath, {
  String? reportPathOverride,
}) {
  final file = File(reportPath);
  if (!file.existsSync()) return const {};

  final lines = file.readAsLinesSync();
  final out = <String, List<WorstSample>>{};

  final gamePattern = RegExp(r'^GAME\s+\d+\s+(.+)$');
  final worstPattern = RegExp(r'worst=([+-]?\d+(?:\.\d+)?)');

  String? currentOpening;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    final gameMatch = gamePattern.firstMatch(line);
    if (gameMatch != null) {
      currentOpening = gameMatch.group(1)!.trim();
      continue;
    }

    if (currentOpening == null) continue;

    final worstMatch = worstPattern.firstMatch(line);
    if (worstMatch != null) {
      final worst = double.tryParse(worstMatch.group(1)!) ?? 0.0;
      out
          .putIfAbsent(currentOpening, () => <WorstSample>[])
          .add(
            WorstSample(
              reportPath: reportPathOverride ?? reportPath,
              line: i + 1,
              worst: worst,
            ),
          );
      currentOpening = null;
    }
  }

  return out;
}

String renderYamlPlan(List<ModPlan> plans, CurateOptions options) {
  final b = StringBuffer();
  b.writeln('generated_at: ${DateTime.now().toIso8601String()}');
  b.writeln('report_window: ${options.reportWindow}');
  b.writeln('rules:');
  b.writeln('  demote_worst_lt: ${options.demoteWorstLt.toStringAsFixed(2)}');
  b.writeln(
    '  promote_worst_gte: ${options.promoteWorstGte.toStringAsFixed(2)}',
  );
  b.writeln('  recurring_reports_required: ${options.recurringReports}');
  b.writeln('mods:');

  for (final plan in plans) {
    b.writeln('  - mod: ${_yamlString(plan.mod)}');
    b.writeln('    baseline: ${_yamlString(plan.baselinePath)}');
    if (plan.warning != null) {
      b.writeln('    warning: ${_yamlString(plan.warning!)}');
    }
    b.writeln('    reports:');
    if (plan.reports.isEmpty) {
      b.writeln('      - ${_yamlString('(none)')}');
    } else {
      for (final report in plan.reports) {
        b.writeln('      - ${_yamlString(report)}');
      }
    }

    final promoteCount = plan.proposals
        .where((p) => p.action == 'promote_to_stress')
        .length;
    final demoteCount = plan.proposals
        .where((p) => p.action == 'demote_to_discovery')
        .length;

    b.writeln('    summary:');
    b.writeln('      openings_observed: ${plan.openingsObserved}');
    b.writeln('      promote_candidates: $promoteCount');
    b.writeln('      demote_candidates: $demoteCount');

    b.writeln('    proposals:');
    if (plan.proposals.isEmpty) {
      b.writeln('      []');
    } else {
      for (var i = 0; i < plan.proposals.length; i++) {
        final p = plan.proposals[i];
        b.writeln('      - action: ${_yamlString(p.action)}');
        b.writeln('        opening: ${_yamlString(p.opening)}');
        b.writeln('        reason: ${_yamlString(p.reason)}');
        b.writeln('        evidence:');
        for (final e in p.evidence) {
          b.writeln('          - report: ${_yamlString(e.reportPath)}');
          b.writeln('            line: ${e.line}');
          b.writeln('            worst: ${e.worst.toStringAsFixed(2)}');
        }
      }
    }

    b.writeln('    queue_entries:');
    if (plan.proposals.isEmpty) {
      b.writeln('      []');
    } else {
      for (var i = 0; i < plan.proposals.length; i++) {
        final p = plan.proposals[i];
        final slug = p.action == 'promote_to_stress' ? 'promote' : 'demote';
        final id = '${plan.mod}-corpus-curation-$slug-${i + 1}';
        final firstEvidence = p.evidence.first;
        b.writeln('      - id: ${_yamlString(id)}');
        b.writeln('        mod: ${_yamlString(plan.mod)}');
        b.writeln('        status: pending');
        b.writeln('        kind: corpus_curation');
        b.writeln('        phase: opening');
        b.writeln('        severity: med');
        b.writeln('        evidence:');
        b.writeln('          report: ${_yamlString(firstEvidence.reportPath)}');
        b.writeln('          line: ${firstEvidence.line}');
        b.writeln('        blunder_threshold_cp: 200');
        b.writeln(
          '        notes: ${_yamlString('${p.action}: ${p.reason} | opening=${p.opening}')}',
        );
      }
    }
  }

  return b.toString();
}

String _relPath(String root, String path) {
  final rootWithSlash = root.endsWith('/') ? root : '$root/';
  if (path.startsWith(rootWithSlash)) {
    return path.substring(rootWithSlash.length);
  }
  return path;
}

String _yamlString(String value) {
  final escaped = value.replaceAll("'", "''");
  return "'$escaped'";
}
