/// Proof test for roadmap §0.3.bullet-1: archive legacy Go backend.
///
/// Final required state:
/// 1. `archive/backend-go-legacy/` exists.
/// 2. `backend/` no longer exists at the repository root.
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

  test('legacy backend moved into archive/backend-go-legacy', () {
    final archivedBackend = Directory('$repoRoot/archive/backend-go-legacy');
    final rootBackend = Directory('$repoRoot/backend');

    expect(
      archivedBackend.existsSync(),
      isTrue,
      reason:
          'Expected archive/backend-go-legacy to exist after Phase 0.3 archiving.',
    );
    expect(
      rootBackend.existsSync(),
      isFalse,
      reason: 'Expected backend/ to be removed from repo root after archiving.',
    );
  });
}