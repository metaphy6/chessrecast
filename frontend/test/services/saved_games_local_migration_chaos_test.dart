/// Proof test for roadmap §0.4.bullet-4 — Reliability.
///
/// Verifies that migration from the legacy JSON-on-disk format
/// (SavedGamesService: one `.json` file per game under `saved_games/`)
/// to the local SQLite store is:
///   (a) correct — all valid game files are imported,
///   (b) idempotent — running twice produces no duplicates,
///   (c) resilient — corrupt / partial files are skipped; the migration
///       completes for the remaining valid files,
///   (d) crash-safe — a migration that was interrupted (simulated by
///       running over only a subset of files) leaves the DB in a valid
///       state, and resuming picks up from where it left off.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/services/saved_game.dart';
import '../../lib/services/saved_games_local.dart';

/// Build a minimal valid SavedGame and serialise it to a JSON file.
void _writeGameFile(Directory dir, String id, {int dayOffset = 0}) {
  final game = SavedGame(
    id: id,
    timestamp: DateTime(2025, 3, 1).add(Duration(days: dayOffset)),
    gameType: 'classic',
    whiteLevel: 'medium',
    blackLevel: 'hard',
    result: 'white',
    resultReason: 'checkmate',
    moveLog: ['e2e4', 'e7e5', 'd2d4'],
    totalMoves: 3,
  );
  File(p.join(dir.path, '$id.json')).writeAsStringSync(game.toJsonString());
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('1. migrate imports all valid legacy JSON games', () async {
    final jsonDir = Directory.systemTemp.createTempSync('legacy_json_');
    final dbDir = Directory.systemTemp.createTempSync('sqlite_db_');
    addTearDown(() {
      jsonDir.deleteSync(recursive: true);
      dbDir.deleteSync(recursive: true);
    });

    _writeGameFile(jsonDir, 'game-a', dayOffset: 0);
    _writeGameFile(jsonDir, 'game-b', dayOffset: 1);
    _writeGameFile(jsonDir, 'game-c', dayOffset: 2);

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dbDir.path);
    await svc.init();

    final imported = await svc.migrateFromLegacyJsonDirectory(jsonDir);
    expect(imported, 3, reason: 'All 3 valid games must be imported');

    final list = await svc.listGames();
    expect(list.length, 3);
    expect(list.map((g) => g.id).toSet(), {'game-a', 'game-b', 'game-c'});

    await svc.close();
  });

  test('2. migration is idempotent — running twice creates no duplicates', () async {
    final jsonDir = Directory.systemTemp.createTempSync('legacy_idem_');
    final dbDir = Directory.systemTemp.createTempSync('sqlite_idem_');
    addTearDown(() {
      jsonDir.deleteSync(recursive: true);
      dbDir.deleteSync(recursive: true);
    });

    _writeGameFile(jsonDir, 'idem-1');
    _writeGameFile(jsonDir, 'idem-2');

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dbDir.path);
    await svc.init();

    final first = await svc.migrateFromLegacyJsonDirectory(jsonDir);
    expect(first, 2);

    // Second run must be a no-op (already migrated).
    final second = await svc.migrateFromLegacyJsonDirectory(jsonDir);
    expect(second, 0, reason: 'Second migration must import 0 new games');

    final list = await svc.listGames();
    expect(list.length, 2, reason: 'No duplicates must exist after double migration');

    await svc.close();
  });

  test('3. corrupt / partial files are skipped; valid ones are imported', () async {
    final jsonDir = Directory.systemTemp.createTempSync('legacy_corrupt_');
    final dbDir = Directory.systemTemp.createTempSync('sqlite_corrupt_');
    addTearDown(() {
      jsonDir.deleteSync(recursive: true);
      dbDir.deleteSync(recursive: true);
    });

    _writeGameFile(jsonDir, 'valid-1');
    _writeGameFile(jsonDir, 'valid-2');
    // Corrupt files
    File(p.join(jsonDir.path, 'corrupt-a.json'))
        .writeAsStringSync('{not valid json >>>');
    File(p.join(jsonDir.path, 'corrupt-b.json'))
        .writeAsStringSync(''); // empty file

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dbDir.path);
    await svc.init();

    final imported = await svc.migrateFromLegacyJsonDirectory(jsonDir);
    expect(imported, 2, reason: 'Only valid files are counted as imported');

    final list = await svc.listGames();
    expect(list.length, 2);
    expect(list.map((g) => g.id), containsAll(['valid-1', 'valid-2']));

    await svc.close();
  });

  test('4. simulated partial migration + resume leaves no gaps', () async {
    final jsonDir = Directory.systemTemp.createTempSync('legacy_partial_');
    final dbDir = Directory.systemTemp.createTempSync('sqlite_partial_');
    addTearDown(() {
      jsonDir.deleteSync(recursive: true);
      dbDir.deleteSync(recursive: true);
    });

    for (var i = 0; i < 5; i++) {
      _writeGameFile(jsonDir, 'pg-$i', dayOffset: i);
    }

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dbDir.path);
    await svc.init();

    // First partial run: directly import only the first 3 games (simulates crash
    // mid-migration after 3 of 5 files are written).
    for (var i = 0; i < 3; i++) {
      final file = File(p.join(jsonDir.path, 'pg-$i.json'));
      final game = SavedGame.fromJsonString(file.readAsStringSync());
      await svc.saveGame(game);
    }

    // Resume: migrateFromLegacyJsonDirectory should pick up the remaining 2.
    final resumed = await svc.migrateFromLegacyJsonDirectory(jsonDir);
    expect(resumed, 2, reason: 'Resume must import only the 2 not-yet-migrated games');

    final list = await svc.listGames();
    expect(list.length, 5, reason: 'All 5 games must be present after resume');

    await svc.close();
  });

  test('5. migration marks completion in meta (legacy_migrated flag)', () async {
    final jsonDir = Directory.systemTemp.createTempSync('legacy_flag_');
    final dbDir = Directory.systemTemp.createTempSync('sqlite_flag_');
    addTearDown(() {
      jsonDir.deleteSync(recursive: true);
      dbDir.deleteSync(recursive: true);
    });

    _writeGameFile(jsonDir, 'flag-1');

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dbDir.path);
    await svc.init();

    await svc.migrateFromLegacyJsonDirectory(jsonDir);

    final migrated = await svc.legacyMigrated();
    expect(migrated, isTrue, reason: 'legacy_migrated flag must be set after migration');

    await svc.close();
  });
}
