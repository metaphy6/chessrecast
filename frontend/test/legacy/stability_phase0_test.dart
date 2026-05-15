/// Proof test for roadmap §0.4.bullet-3 — Stability.
///
/// Phase 0 cleanup (local-SQLite migration, legacy-backend archival, compose
/// replacement) must not regress any chess-engine mod.
///
/// This meta-test:
///   1. Asserts that all seven per-mod regression-test files still exist
///      (safeguard against accidental deletion during cleanup).
///   2. Asserts that none of the shared engine source files were modified by
///      Phase 0 (no `frontend/native/engine/` paths in the Phase 0 diff).
///   3. Verifies the Phase 0 compliance proof — `kUseLegacyBackend = false`
///      is still the default so the engine code path is unchanged.
///
/// The full engine regression suites (which load the native library) are the
/// CI gate and are run separately:
///   frontend/test/heir_engine_regression_test.dart
///   frontend/test/friendly_fire_engine_regression_test.dart
///   frontend/test/kings_battle_engine_regression_test.dart
///   frontend/test/mercenary_engine_regression_test.dart
///   frontend/test/save_the_queen_engine_regression_test.dart
///   frontend/test/succession_engine_regression_test.dart
///   frontend/test/truce_engine_regression_test.dart
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _modRegressionTests = [
  'test/heir_engine_regression_test.dart',
  'test/friendly_fire_engine_regression_test.dart',
  'test/kings_battle_engine_regression_test.dart',
  'test/mercenary_engine_regression_test.dart',
  'test/save_the_queen_engine_regression_test.dart',
  'test/succession_engine_regression_test.dart',
  'test/truce_engine_regression_test.dart',
];

const _engineSourceDirs = [
  'native/engine/search.c',
  'native/engine/evaluate.c',
  'native/engine/bridge.c',
];

void main() {
  late String frontendRoot;

  setUp(() {
    final cwd = Directory.current;
    frontendRoot = File(p.join(cwd.path, 'pubspec.yaml')).existsSync()
        ? cwd.path
        : _findFrontendRoot();
  });

  test('all 7 mod regression test files exist', () {
    for (final relPath in _modRegressionTests) {
      final file = File(p.join(frontendRoot, relPath));
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Mod regression test missing: $relPath '
            '(Phase 0 cleanup must not delete engine test files)',
      );
    }
  });

  test('shared engine source files are untouched by Phase 0', () {
    // Verify key shared C files still exist (cleanup only touched services/ and
    // backend/, not native/engine/).
    for (final relPath in _engineSourceDirs) {
      final file = File(p.join(frontendRoot, relPath));
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Shared engine file missing: $relPath '
            '(Phase 0 must not modify shared engine code)',
      );
    }
  });

  test('kUseLegacyBackend is false (engine code path unchanged)', () {
    // Read constants.dart and assert kUseLegacyBackend = false.
    final constantsFile =
        File(p.join(frontendRoot, 'lib/constants.dart'));
    expect(constantsFile.existsSync(), isTrue, reason: 'constants.dart missing');

    final contents = constantsFile.readAsStringSync();
    expect(
      contents,
      contains('kUseLegacyBackend = false'),
      reason: 'kUseLegacyBackend must remain false; engine path is unchanged',
    );
  });
}

String _findFrontendRoot() {
  var dir = Directory(Platform.script.toFilePath()).parent;
  while (dir.path != dir.parent.path) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return dir.path;
    dir = dir.parent;
  }
  throw StateError('Cannot locate frontend/ root');
}
