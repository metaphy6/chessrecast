// §12.1 T-P-WPC — Watched-paths completeness gate for ENGINE_REPLAY_VERSION.
//
// Every .c and .h file under frontend/native/engine/ must be either:
//   (a) covered by the CI watched-paths globs in
//       .github/workflows/engine-replay-version-bump-required.yml, OR
//   (b) explicitly listed in
//       frontend/native/engine/replay_version_excluded_paths.txt
//       with a rationale comment.
//
// This prevents new native engine files from silently bypassing the
// replay-version bump gate.
//
// Pre-implementation state: replay_version_excluded_paths.txt did not exist →
//   test failed on FileSystemException.
// Post-implementation state: file exists, every .c/.h is categorized → passes.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// CI-watched glob patterns (must stay in sync with
// .github/workflows/engine-replay-version-bump-required.yml).
// ---------------------------------------------------------------------------

/// Returns true if [relPath] (relative to frontend/native/engine/) is covered
/// by the CI watched-paths globs.
bool _isCiWatched(String relPath) {
  // Subdirectory globs: board/**, bridge/**, eval/**, movegen/**
  const watchedDirs = {'board', 'bridge', 'eval', 'movegen'};
  final parts = relPath.split('/');
  if (parts.length > 1 && watchedDirs.contains(parts.first)) return true;

  // Top-level files that affect rule semantics.
  const watchedTopLevel = {
    'board.c',
    'board.h',
    'bridge.c',
    'evaluate.c',
    'evaluate.h',
    'movegen.c',
    'movegen.h',
    'types.h',
  };
  return watchedTopLevel.contains(relPath);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Set<String> _loadExcludedPaths(String engineRoot) {
  final file = File('$engineRoot/replay_version_excluded_paths.txt');
  if (!file.existsSync()) return {};
  return file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

List<String> _allEngineSourceFiles(String engineRoot) {
  final dir = Directory(engineRoot);
  if (!dir.existsSync()) return [];

  final results = <String>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File) {
      final path = entity.path;
      if (path.endsWith('.c') || path.endsWith('.h')) {
        // Make relative to engineRoot.
        final rel = path.substring(engineRoot.length + 1);
        results.add(rel);
      }
    }
  }
  results.sort();
  return results;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('§12.1 Watched-paths completeness', () {
    late String engineRoot;

    setUpAll(() {
      final cwd = Directory.current.path;
      final candidates = [
        '$cwd/native/engine',
        '$cwd/../frontend/native/engine',
        '$cwd/frontend/native/engine',
      ];
      engineRoot = candidates.firstWhere(
        (p) => Directory(p).existsSync(),
        orElse: () => candidates.first,
      );
    });

    test('replay_version_excluded_paths.txt exists', () {
      expect(
        File('$engineRoot/replay_version_excluded_paths.txt').existsSync(),
        isTrue,
        reason:
            'frontend/native/engine/replay_version_excluded_paths.txt must '
            'exist (Phase 12.1). Create it to list files excluded from the '
            'ENGINE_REPLAY_VERSION bump gate.',
      );
    });

    test('every .c/.h file is either CI-watched or explicitly excluded', () {
      final allFiles = _allEngineSourceFiles(engineRoot);
      expect(
        allFiles,
        isNotEmpty,
        reason: 'Expected to find .c/.h files under $engineRoot',
      );

      final excluded = _loadExcludedPaths(engineRoot);

      final uncategorized = <String>[];
      for (final f in allFiles) {
        if (!_isCiWatched(f) && !excluded.contains(f)) {
          uncategorized.add(f);
        }
      }

      expect(
        uncategorized,
        isEmpty,
        reason:
            'The following native engine files are neither covered by the CI '
            'watched-paths globs nor listed in '
            'replay_version_excluded_paths.txt:\n'
            '${uncategorized.map((f) => '  - $f').join('\n')}\n\n'
            'Action: add each file to EITHER the watched paths in '
            '.github/workflows/engine-replay-version-bump-required.yml '
            '(if it affects rule semantics) OR to '
            'replay_version_excluded_paths.txt (if it does not).',
      );
    });

    test('excluded paths file lists only files that actually exist', () {
      final excluded = _loadExcludedPaths(engineRoot);
      if (excluded.isEmpty) return; // empty file is acceptable

      final missing = <String>[];
      for (final rel in excluded) {
        if (!File('$engineRoot/$rel').existsSync()) {
          missing.add(rel);
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'replay_version_excluded_paths.txt references non-existent files:\n'
            '${missing.map((f) => '  - $f').join('\n')}\n'
            'Remove stale entries.',
      );
    });
  });
}
