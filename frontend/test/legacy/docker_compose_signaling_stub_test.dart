/// Proof test for roadmap §0.3.bullet-2: docker compose replacement.
///
/// Final required state:
/// 1. Root `docker-compose.yml` does not exist.
/// 2. Root `docker-compose.signaling.yml` exists.
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

  test('legacy root compose removed and signaling compose exists', () {
    final rootCompose = File('$repoRoot/docker-compose.yml');
    final signalingCompose = File('$repoRoot/docker-compose.signaling.yml');

    expect(
      rootCompose.existsSync(),
      isFalse,
      reason: 'Root docker-compose.yml must be removed in Phase 0.3.',
    );
    expect(
      signalingCompose.existsSync(),
      isTrue,
      reason: 'Root docker-compose.signaling.yml must exist as the Phase 0.3 stub.',
    );
  });
}