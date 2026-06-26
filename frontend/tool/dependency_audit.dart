// frontend/tool/dependency_audit.dart
//
// Flutter / Dart dependency audit. Runs `flutter pub outdated --json` and
// `dart pub outdated --json` (frontend only -- backend Go modules are
// intentionally out of scope; the Go backend is slated for replacement
// by a P2P stack and we do not invest churn there).
//
// Writes a markdown report to bots/reports/_security/<run-id>.md and
// appends `kind: security` queue entries to bots/queue.yaml for any
// dependency where the latest resolvable version is more than one major
// version ahead, OR where the package is in the well-known
// security-sensitive list.
//
// Usage (from frontend/):
//   dart run tool/dependency_audit.dart [--write-queue]
//
// --write-queue : actually append to bots/queue.yaml (default: dry-run,
//                 print the entries it would add).

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const _securitySensitive = <String>{
  'http',
  'dio',
  'web_socket_channel',
  'crypto',
  'cryptography',
  'jwt_decoder',
  'shared_preferences',
  'flutter_secure_storage',
  'url_launcher',
  'webview_flutter',
};

void main(List<String> args) async {
  final writeQueue = args.contains('--write-queue');
  final repoRoot = _findRepoRoot();
  final outDir = Directory('${repoRoot.path}/bots/reports/_security');
  outDir.createSync(recursive: true);

  final runId = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
  final outPath = '${outDir.path}/$runId.md';
  final buf = StringBuffer()
    ..writeln('# dependency audit — frontend')
    ..writeln()
    ..writeln('generated_at: ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln();

  final findings = <_Finding>[];

  // flutter pub outdated --json
  final res = await Process.run('flutter', [
    'pub',
    'outdated',
    '--json',
    '--mode=null-safety',
  ]);
  if (res.exitCode != 0) {
    buf.writeln('## flutter pub outdated');
    buf.writeln('FAILED (exit ${res.exitCode}):');
    buf.writeln('```');
    buf.writeln(res.stderr);
    buf.writeln('```');
  } else {
    try {
      final j = jsonDecode(res.stdout as String) as Map<String, dynamic>;
      final pkgs = (j['packages'] as List?) ?? const [];
      buf.writeln('## flutter pub outdated (${pkgs.length} packages tracked)');
      buf.writeln();
      buf.writeln('| package | current | resolvable | latest | concern |');
      buf.writeln('| --- | --- | --- | --- | --- |');
      for (final p in pkgs) {
        final m = p as Map<String, dynamic>;
        final name = m['package'] as String? ?? '?';
        final current = (m['current'] as Map?)?['version'] as String? ?? '—';
        final resolvable =
            (m['resolvable'] as Map?)?['version'] as String? ?? '—';
        final latest = (m['latest'] as Map?)?['version'] as String? ?? '—';
        final concern = _classify(name, current, latest);
        if (concern != null) {
          findings.add(_Finding(name, current, latest, concern));
          buf.writeln(
            '| `$name` | $current | $resolvable | $latest | $concern |',
          );
        }
      }
      if (findings.isEmpty) {
        buf.writeln('| _no dependencies of concern_ | | | | |');
      }
    } catch (e) {
      buf.writeln('## flutter pub outdated');
      buf.writeln('PARSE FAILED: $e');
      buf.writeln('```');
      buf.writeln(res.stdout);
      buf.writeln('```');
    }
  }

  buf.writeln();
  buf.writeln('## queue entries that would be filed');
  if (findings.isEmpty) {
    buf.writeln('_(none)_');
  } else {
    for (final f in findings) {
      buf.writeln('- ${f.package} ${f.current} -> ${f.latest} (${f.reason})');
    }
  }

  File(outPath).writeAsStringSync(buf.toString());
  print('dependency_audit: report written to $outPath');
  print('dependency_audit: ${findings.length} finding(s) of concern.');

  if (writeQueue && findings.isNotEmpty) {
    final qfile = File('${repoRoot.path}/bots/queue.yaml');
    final sink = qfile.openWrite(mode: FileMode.append);
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final f in findings) {
      sink.writeln();
      sink.writeln('- id: shared-depaudit-${f.package}-$stamp');
      sink.writeln('  mod: shared');
      sink.writeln('  status: pending');
      sink.writeln('  kind: shared_edit');
      sink.writeln('  phase: strategy');
      sink.writeln('  severity: med');
      sink.writeln('  evidence:');
      sink.writeln('    report: ${_relPath(outPath, repoRoot.path)}');
      sink.writeln('    line: 0');
      sink.writeln(
        '  notes: "Dependency ${f.package} ${f.current} -> ${f.latest} (${f.reason}); review changelog and bump."',
      );
    }
    await sink.flush();
    await sink.close();
    print('dependency_audit: appended ${findings.length} queue entries.');
  } else if (findings.isNotEmpty) {
    print(
      'dependency_audit: dry-run (pass --write-queue to append queue entries).',
    );
  }
}

String? _classify(String name, String current, String latest) {
  if (current == '—' || latest == '—' || current == latest) return null;
  final cM = _major(current);
  final lM = _major(latest);
  final reasons = <String>[];
  if (lM != null && cM != null && lM - cM >= 1) {
    reasons.add('major bump $cM->$lM');
  }
  if (_securitySensitive.contains(name)) {
    reasons.add('security-sensitive package');
  }
  return reasons.isEmpty ? null : reasons.join('; ');
}

int? _major(String v) {
  final clean = v.replaceAll(RegExp(r'^[\^~>=<]+'), '').trim();
  final m = RegExp(r'^(\d+)').firstMatch(clean);
  return m == null ? null : int.tryParse(m.group(1)!);
}

class _Finding {
  final String package;
  final String current;
  final String latest;
  final String reason;
  _Finding(this.package, this.current, this.latest, this.reason);
}

Directory _findRepoRoot() {
  var d = Directory.current;
  while (true) {
    if (Directory('${d.path}/.git').existsSync()) return d;
    final parent = d.parent;
    if (parent.path == d.path) throw StateError('not inside a git repo');
    d = parent;
  }
}

String _relPath(String absPath, String root) {
  if (absPath.startsWith(root)) {
    final rel = absPath.substring(root.length);
    return rel.startsWith('/') ? rel.substring(1) : rel;
  }
  return absPath;
}
