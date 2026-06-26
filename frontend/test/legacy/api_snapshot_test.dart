/// Proof test for roadmap §0.1.bullet-3: Legacy API snapshot.
///
/// Verifies:
/// 1. `docs/p2p/P2P_LEGACY_API_SNAPSHOT.md` exists and is non-empty.
/// 2. The snapshot references each known REST endpoint path.
/// 3. The snapshot references the WebSocket endpoint path.
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repoRoot;
  late File snapshot;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    repoRoot = dir.path;
    snapshot = File('$repoRoot/docs/p2p/P2P_LEGACY_API_SNAPSHOT.md');
  });

  test('P2P_LEGACY_API_SNAPSHOT.md exists', () {
    expect(
      snapshot.existsSync(),
      isTrue,
      reason: 'docs/p2p/P2P_LEGACY_API_SNAPSHOT.md must be created.',
    );
    expect(
      snapshot.readAsStringSync().length,
      greaterThan(200),
      reason: 'Snapshot must contain substantial content.',
    );
  });

  group('REST endpoints documented', () {
    late String content;
    setUpAll(() => content = snapshot.readAsStringSync());

    for (final path in [
      '/auth/guest',
      '/games',
      '/games/{id}',
      '/games/{id}/moves',
      '/games/{id}/resign',
      '/bots',
    ]) {
      test('documents $path', () {
        expect(
          content.contains(path),
          isTrue,
          reason: 'Snapshot must document REST endpoint $path.',
        );
      });
    }
  });

  test('WebSocket endpoint documented', () {
    final content = snapshot.readAsStringSync();
    expect(
      content.contains('/ws/game/'),
      isTrue,
      reason: 'Snapshot must document the WebSocket endpoint /ws/game/{id}.',
    );
  });
}
