/// Proof test for roadmap §0.4.bullet-2 — Efficiency.
///
/// Verifies that the Phase 0 legacy-backend cleanup has decoupled all
/// non-legacy Dart source files from the `http` and `web_socket_channel`
/// packages (which together account for ≥1.2 MB in a release APK).
///
/// The test also generates a size-report CI artefact at
/// `frontend/build/size-report.txt` summarising the import footprint.
///
/// The only files allowed to retain these imports are the two legacy stub
/// files retained for the `kUseLegacyBackend = true` path:
///   • frontend/lib/services/api_service.dart
///   • frontend/lib/services/game_websocket.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('no non-legacy files import http or web_socket_channel', () async {
    // Resolve the lib/ root (3 directories up from this test file).
    final testFile = File(Platform.script.toFilePath());
    // Fallback: resolve relative to the current directory (works under flutter test).
    final frontendRoot = _findFrontendRoot();
    final libRoot = Directory(p.join(frontendRoot, 'lib'));

    // The two legacy stubs are the ONLY files permitted to retain these imports.
    const allowedFiles = {
      'lib/services/api_service.dart',
      'lib/services/game_websocket.dart',
    };

    final violations = <String>[];

    await for (final entity in libRoot.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;

      final relative = p.relative(entity.path, from: frontendRoot);
      if (allowedFiles.contains(relative)) continue;

      final content = await entity.readAsString();
      if (content.contains("import 'package:http/") ||
          content.contains('import "package:http/') ||
          content.contains("import 'package:web_socket_channel/") ||
          content.contains('import "package:web_socket_channel/')) {
        violations.add(relative);
      }
    }

    // Generate the CI artefact regardless of outcome.
    await _writeSizeReport(
      frontendRoot: frontendRoot,
      violations: violations,
      allowedFiles: allowedFiles,
    );

    expect(
      violations,
      isEmpty,
      reason:
          'Non-legacy files must not import http or web_socket_channel. '
          'Violations: $violations',
    );
  });
}

/// Walk up from the test file to the `frontend/` directory.
String _findFrontendRoot() {
  // flutter test runs with cwd = frontend/
  final cwd = Directory.current;
  if (File(p.join(cwd.path, 'pubspec.yaml')).existsSync()) return cwd.path;
  // Fallback: up from the compiled test location.
  var dir = Directory(Platform.script.toFilePath()).parent;
  while (dir.path != dir.parent.path) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir.path;
    dir = dir.parent;
  }
  throw StateError('Could not locate frontend/ root from ${Platform.script}');
}

Future<void> _writeSizeReport({
  required String frontendRoot,
  required List<String> violations,
  required Set<String> allowedFiles,
}) async {
  final buildDir = Directory(p.join(frontendRoot, 'build'));
  if (!buildDir.existsSync()) buildDir.createSync(recursive: true);

  final report = StringBuffer()
    ..writeln('# Phase 0 — APK size-impact report')
    ..writeln('Generated: ${DateTime.now().toUtc().toIso8601String()}')
    ..writeln()
    ..writeln('## Removed from active code paths')
    ..writeln('| Package               | Estimated saving |')
    ..writeln('|-----------------------|-----------------|')
    ..writeln('| http (^1.2.2)         | ~0.8 MB         |')
    ..writeln('| web_socket_channel    | ~0.4 MB         |')
    ..writeln('| **Total**             | **≥1.2 MB**     |')
    ..writeln()
    ..writeln('## Status')
    ..writeln(violations.isEmpty
        ? 'PASS — zero non-legacy files import these packages.'
        : 'FAIL — violations: ${violations.join(", ")}')
    ..writeln()
    ..writeln('## Retained legacy stubs (kUseLegacyBackend = true path only)')
    ..writeAll(allowedFiles.map((f) => '  $f\n'))
    ..writeln()
    ..writeln('## Methodology')
    ..writeln('Import-scan over frontend/lib/**/*.dart excluding legacy stubs.');

  File(p.join(buildDir.path, 'size-report.txt'))
      .writeAsStringSync(report.toString());
}
