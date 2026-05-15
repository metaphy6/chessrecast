/// Proof test for roadmap §0.1.bullet-2: Go backend freeze.
///
/// Verifies:
/// 1. The git tag `backend-legacy-final` exists in the repo.
/// 2. `backend/README.md` exists and contains the freeze notice.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) {
        fail('Could not locate repo root.');
      }
      dir = parent;
    }
    repoRoot = dir.path;
  });

  test('git tag backend-legacy-final exists', () {
    final result = Process.runSync('git', ['tag', '--list', 'backend-legacy-final'],
        workingDirectory: repoRoot);
    expect(result.exitCode, 0, reason: 'git tag --list should succeed');
    expect(
      (result.stdout as String).trim(),
      'backend-legacy-final',
      reason:
          'The tag backend-legacy-final must be present. '
          'Create it with: git tag backend-legacy-final',
    );
  });

  test('backend/README.md contains the freeze notice', () {
    final readme = File('$repoRoot/backend/README.md');
    expect(
      readme.existsSync(),
      isTrue,
      reason: 'backend/README.md must exist with a freeze notice.',
    );
    final content = readme.readAsStringSync();
    expect(
      content.contains('backend-legacy-final'),
      isTrue,
      reason:
          'backend/README.md must reference the freeze tag backend-legacy-final.',
    );
    expect(
      content.contains('P2P_ROADMAP.md') || content.contains('P2P Roadmap'),
      isTrue,
      reason: 'backend/README.md must point to the P2P roadmap.',
    );
  });
}
