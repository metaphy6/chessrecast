/// Proof test for roadmap §0.1.bullet-1: Legacy backend usages inventory.
///
/// This test:
/// 1. Verifies that docs/code/LEGACY_BACKEND_USAGES.md exists and is
///    non-empty (the inventory document).
/// 2. Verifies that the set of Dart files in frontend/lib/** that import one
///    of the four legacy service files matches EXACTLY the set listed in the
///    inventory document.  Any new file added after the freeze that imports a
///    legacy service will be caught by the second assertion.
///
/// The four legacy service files (the "freeze set"):
///   - lib/services/api_service.dart
///   - lib/services/game_websocket.dart
///   - lib/services/saved_game.dart
///   - lib/services/saved_games_service.dart
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Relative import patterns that identify each legacy file.
const _legacyImports = <String>[
  'api_service.dart',
  'game_websocket.dart',
  'saved_game.dart',
  'saved_games_service.dart',
];

/// Walk frontend/lib recursively and return the workspace-relative paths of
/// every .dart file that contains at least one legacy import.
List<String> _findLegacyImporters(Directory libDir, String repoRoot) {
  final found = <String>[];
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final content = entity.readAsStringSync();
    final hasLegacy = _legacyImports.any(
      (imp) => content.contains(imp),
    );
    if (hasLegacy) {
      final rel = entity.path.replaceFirst('$repoRoot/', '');
      found.add(rel);
    }
  }
  found.sort();
  return found;
}

/// Parse the documented importer paths from LEGACY_BACKEND_USAGES.md.
/// Lines that begin with "- `frontend/lib/` path entries are collected.
List<String> _parseDocumentedImporters(File doc) {
  final lines = doc.readAsLinesSync();
  final result = <String>[];
  for (final line in lines) {
    // Lines like: | `frontend/lib/...` | ... |  (table rows)
    final tableMatch = RegExp(r'\|\s*`(frontend/lib/[^`]+)`').firstMatch(line);
    if (tableMatch != null) {
      result.add(tableMatch.group(1)!.trim());
      continue;
    }
    // Lines like: - `frontend/lib/...`  (list items)
    final listMatch = RegExp(r'-\s*`(frontend/lib/[^`]+)`').firstMatch(line);
    if (listMatch != null) {
      result.add(listMatch.group(1)!.trim());
    }
  }
  result.sort();
  return result;
}

void main() {
  // Locate the repo root relative to the test file location.
  // When run via `flutter test` from frontend/, the cwd is frontend/.
  late final String repoRoot;
  late final File inventoryDoc;

  setUpAll(() {
    // Determine repo root: go up from cwd until we find AGENTS.md
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) {
        fail(
          'Could not locate repo root (AGENTS.md not found). '
          'Run this test from within the repository.',
        );
      }
      dir = parent;
    }
    repoRoot = dir.path;
    inventoryDoc = File('$repoRoot/docs/code/LEGACY_BACKEND_USAGES.md');
  });

  test('LEGACY_BACKEND_USAGES.md exists and is non-empty', () {
    expect(
      inventoryDoc.existsSync(),
      isTrue,
      reason:
          'docs/code/LEGACY_BACKEND_USAGES.md must be created as part of '
          'roadmap §0.1.bullet-1. Run /implement-roadmap INCLUDE=0.1.bullet-1.',
    );
    expect(
      inventoryDoc.readAsStringSync().trim().isNotEmpty,
      isTrue,
      reason: 'The inventory document must not be empty.',
    );
  });

  test(
    'Actual legacy importers match the inventory document (no undocumented '
    'new files added since the freeze)',
    () {
      if (!inventoryDoc.existsSync()) {
        // Inventory doc does not exist yet — test will fail via the first test.
        return;
      }

      final libDir = Directory('$repoRoot/frontend/lib');
      expect(libDir.existsSync(), isTrue);

      final actual = _findLegacyImporters(libDir, repoRoot);
      final documented = _parseDocumentedImporters(inventoryDoc);

      expect(
        actual,
        unorderedEquals(documented),
        reason:
            'The set of Dart files importing a legacy service must match the '
            'inventory in docs/code/LEGACY_BACKEND_USAGES.md.\n'
            'Actual: $actual\n'
            'Documented: $documented\n'
            'If a new file was added that imports a legacy service, update the '
            'inventory doc or remove the legacy import.',
      );
    },
  );
}
