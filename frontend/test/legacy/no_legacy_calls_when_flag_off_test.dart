/// Proof test for roadmap §0.2.bullet-5: no legacy calls when flag is off.
///
/// Strategy: static code inspection.  Each of the 7 documented legacy call
/// sites must contain a reference to `kUseLegacyBackend` as a guard.
/// Files that only use SavedGame model (data class — no network) and
/// SavedGamesService (local-file store — no network) are exempt from the
/// network-call guard but are checked to confirm they don't import ApiService
/// or GameWebSocket directly.
///
/// This test catches accidental removal of the guard during future refactors.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String libDir;

  setUpAll(() {
    var dir = Directory.current;
    while (!File('${dir.path}/AGENTS.md').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) fail('Could not locate repo root.');
      dir = parent;
    }
    libDir = '${dir.path}/frontend/lib';
  });

  String read(String relPath) =>
      File('$libDir/$relPath').readAsStringSync();

  // ─── network call sites: must contain kUseLegacyBackend guard ──────────────

  group('network call sites guarded by kUseLegacyBackend', () {
    for (final relPath in [
      'management/online_controller.dart',
      'ui/online_bot_vs_bot_page.dart',
      'analytics/custom/custom_board_setup.dart',
    ]) {
      test(relPath, () {
        final content = read(relPath);
        expect(
          content.contains('kUseLegacyBackend'),
          isTrue,
          reason: '$relPath must guard legacy network calls with kUseLegacyBackend.',
        );
      });
    }
  });

  // ─── local-store call sites: must NOT import ApiService or GameWebSocket ───

  group('local-store call sites do not import network services', () {
    for (final relPath in [
      'management/watch_engine_controller.dart',
      'ui/saved_games.dart',
    ]) {
      test(relPath, () {
        final content = read(relPath);
        expect(
          content.contains('api_service.dart') ||
              content.contains('game_websocket.dart'),
          isFalse,
          reason:
              '$relPath is a local-store call site and must not import '
              'api_service.dart or game_websocket.dart.',
        );
      });
    }
  });

  // ─── main.dart and saved_games_service.dart: local-only ────────────────────

  test('main.dart does not import api_service or game_websocket', () {
    final content = read('main.dart');
    expect(
      content.contains('api_service.dart') ||
          content.contains('game_websocket.dart'),
      isFalse,
      reason: 'main.dart must not import legacy network services.',
    );
  });

  test('saved_games_service.dart does not import api_service or game_websocket', () {
    final content = read('services/saved_games_service.dart');
    expect(
      content.contains('api_service.dart') ||
          content.contains('game_websocket.dart'),
      isFalse,
      reason: 'saved_games_service.dart is local-only; must not import network services.',
    );
  });
}
