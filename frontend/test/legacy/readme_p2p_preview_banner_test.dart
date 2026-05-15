/// Proof test for roadmap §0.3.bullet-3: README P2P preview banner.
///
/// Final required state:
/// 1. README has a clear "P2P preview not yet shipped" banner.
/// 2. README no longer contains legacy backend run instructions (`cd backend`).
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

  test('README contains P2P preview banner and no backend run commands', () {
    final readme = File('$repoRoot/README.md');
    expect(readme.existsSync(), isTrue, reason: 'README.md must exist at repo root.');

    final content = readme.readAsStringSync();
    expect(
      content.contains('P2P preview not yet shipped'),
      isTrue,
      reason: 'README must include the Phase 0.3 P2P preview banner.',
    );
    expect(
      content.contains('cd backend'),
      isFalse,
      reason: 'README must not contain legacy backend run instructions.',
    );
  });
}