// frontend/tool/scan_runtime_telemetry.dart
//
// Scan recent run logs (under /tmp/agent-runs/ and any caller-supplied paths)
// for runtime crash / illegal-move / assertion telemetry emitted by the
// native engine via stderr. Aggregates findings into
// bots/reports/_runtime/<run-id>.txt so the next agent session can scan them.
//
// Usage (from frontend/):
//   dart run tool/scan_runtime_telemetry.dart [extra log paths...]
//
// Exits 0 on success (whether or not findings were observed). Exits 2 on
// I/O errors so a CI / cron caller can distinguish "tool broken" from
// "found stuff".

// ignore_for_file: avoid_print

import 'dart:io';

const _tokens = <String>[
  'ILLEGAL_MOVE',
  'ASSERT_FAIL',
  'assertion failed',
  'SIGSEGV',
  'SIGABRT',
  'Aborted',
  'cannot open shared object',
  'stack smashing detected',
  'AddressSanitizer',
  'undefined behavior',
];

void main(List<String> args) async {
  try {
    final repoRoot = _findRepoRoot();
    final runtimeDir = Directory('${repoRoot.path}/bots/reports/_runtime');
    runtimeDir.createSync(recursive: true);

    final candidates = <File>[];
    final tmpDir = Directory('/tmp/agent-runs');
    if (tmpDir.existsSync()) {
      for (final e in tmpDir.listSync(recursive: false)) {
        if (e is File && e.path.endsWith('.log')) candidates.add(e);
      }
    }
    for (final p in args) {
      final f = File(p);
      if (f.existsSync()) candidates.add(f);
    }

    if (candidates.isEmpty) {
      print('scan_runtime_telemetry: no log files to scan.');
      return;
    }

    final findings = <_Finding>[];
    for (final f in candidates) {
      final content = await f.readAsString();
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final tok in _tokens) {
          if (line.contains(tok)) {
            findings.add(_Finding(f.path, i + 1, tok, line.trim()));
            break;
          }
        }
      }
    }

    final runId = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final outFile = File('${runtimeDir.path}/$runId.txt');
    final buf = StringBuffer()
      ..writeln('# runtime telemetry scan')
      ..writeln('generated_at: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('scanned_files: ${candidates.length}')
      ..writeln('findings: ${findings.length}')
      ..writeln('---');
    if (findings.isEmpty) {
      buf.writeln('clean.');
    } else {
      for (final f in findings) {
        buf.writeln('${f.token}\t${f.file}:${f.line}\t${f.snippet}');
      }
    }
    outFile.writeAsStringSync(buf.toString());

    if (findings.isEmpty) {
      print(
        'scan_runtime_telemetry: clean across ${candidates.length} log(s). '
        'wrote ${outFile.path}',
      );
    } else {
      print(
        'scan_runtime_telemetry: ${findings.length} finding(s) across '
        '${candidates.length} log(s). wrote ${outFile.path}',
      );
      for (final f in findings.take(10)) {
        print('  ${f.token}  ${f.file}:${f.line}');
      }
      if (findings.length > 10) {
        print('  (+${findings.length - 10} more — see report file)');
      }
    }
  } catch (e, st) {
    stderr.writeln('scan_runtime_telemetry: error: $e\n$st');
    exit(2);
  }
}

class _Finding {
  final String file;
  final int line;
  final String token;
  final String snippet;
  _Finding(this.file, this.line, this.token, this.snippet);
}

Directory _findRepoRoot() {
  var d = Directory.current;
  while (true) {
    if (Directory('${d.path}/.git').existsSync()) return d;
    final parent = d.parent;
    if (parent.path == d.path) {
      throw StateError('not inside a git repo');
    }
    d = parent;
  }
}
