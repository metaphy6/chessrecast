/// Proof test for roadmap §0.4.bullet-5 — Integrity.
///
/// Verifies that no legacy backend URL or credential remains in the
/// production Flutter source tree after Phase-0.3 cleanup, and that
/// the `scan_secrets.dart` tool exits clean on the current HEAD.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Patterns that must NOT appear in production source files.
/// (Allowlist entries are handled per-file below.)
final _forbiddenPatterns = [
  // Hard-coded backend hostnames that were retired in Phase 0.3.
  RegExp(r'chessrecast[-.]backend', caseSensitive: false),
  RegExp(r'api\.chessrecast\.', caseSensitive: false),
  RegExp(r'https?://\S+chessrecast\S+/api/', caseSensitive: false),
  // AWS / Google / Stripe / GitHub credential patterns (mirrors scan_secrets.dart).
  RegExp(r'AKIA[0-9A-Z]{16}'),
  RegExp(r'AIza[0-9A-Za-z\-_]{35}'),
  RegExp(r'ghp_[A-Za-z0-9]{36}'),
  RegExp(r'sk_live_[0-9A-Za-z]{24,}'),
  RegExp(r'-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'),
];

/// Files that are allowed to contain localhost/IP URLs (legacy API stubs).
const _urlAllowList = {
  'lib/services/api_service.dart',
  'lib/services/game_websocket.dart',
};

void main() {
  test('scan_secrets.dart exits clean on HEAD', () async {
    // When run via `flutter test` from the `frontend/` directory,
    // Directory.current is `frontend/`.
    final frontendDir = Directory.current.path;
    final scanScript = p.join(frontendDir, 'tool', 'scan_secrets.dart');

    final result = await Process.run('dart', [
      'run',
      scanScript,
      'HEAD',
    ], workingDirectory: frontendDir);

    expect(
      result.exitCode,
      0,
      reason:
          'scan_secrets.dart must exit 0 on HEAD.\n'
          'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
  });

  test('no hardcoded legacy backend credentials in production source', () async {
    final frontendDir = Directory.current.path;
    final libDir = Directory(p.join(frontendDir, 'lib'));
    expect(libDir.existsSync(), isTrue, reason: 'frontend/lib must exist');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final rel = p.relative(entity.path, from: frontendDir);
      final isAllowListed = _urlAllowList.any(
        (allowed) => rel.endsWith(allowed),
      );

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final pattern in _forbiddenPatterns) {
          // For URL-based patterns, skip allow-listed files.
          if (isAllowListed && pattern.pattern.contains(r'https?://')) {
            continue;
          }
          if (pattern.hasMatch(line)) {
            violations.add('$rel:${i + 1}  ${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Found legacy backend credentials / URLs:\n${violations.join('\n')}',
    );
  });
}
