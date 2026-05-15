/// Proof test for roadmap §0.2.bullet-2: schema migration policy.
///
/// Tests:
/// 1. A SavedGame written at schema v1 round-trips through the v1 reader without
///    any lossy fields.
/// 2. When a v2 schema adds an optional column, a v1-era payload (missing the
///    new field) still loads without error (null default).
/// 3. The migration helper in SavedGamesLocal records the new version in meta.
/// 4. Irreversible migration marker: SavedGamesLocal exposes
///    `downMigrationBlocked` = true, documenting that down-grades are unsupported.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/services/saved_game.dart';
import '../../lib/services/saved_games_local.dart';

SavedGame makeGame(String id) => SavedGame(
      id: id,
      timestamp: DateTime(2025, 3, 15),
      gameType: 'mercenary',
      whiteLevel: 'hard',
      blackLevel: 'expert',
      result: 'draw',
      resultReason: 'stalemate',
      moveLog: ['d2d4', 'd7d5', 'c2c4'],
      totalMoves: 3,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('1. v1→v1 round-trip preserves all fields', () async {
    final svc = SavedGamesLocal.forTesting(inMemory: true);
    await svc.init();

    final original = makeGame('rt-001');
    await svc.saveGame(original);
    final loaded = await svc.loadGame('rt-001');

    expect(loaded, isNotNull);
    expect(loaded!.id, original.id);
    expect(loaded.gameType, original.gameType);
    expect(loaded.whiteLevel, original.whiteLevel);
    expect(loaded.blackLevel, original.blackLevel);
    expect(loaded.result, original.result);
    expect(loaded.resultReason, original.resultReason);
    expect(loaded.moveLog, original.moveLog);
    expect(loaded.totalMoves, original.totalMoves);
    expect(
      loaded.timestamp.toIso8601String(),
      original.timestamp.toIso8601String(),
    );
    await svc.close();
  });

  test('2. v1-era payload missing new optional field loads without error', () async {
    // Simulate a pre-v2 payload that lacks a hypothetical new field by inserting
    // a raw JSON blob that omits "fenHistory" (already optional in SavedGame).
    final svc = SavedGamesLocal.forTesting(inMemory: true);
    await svc.init();

    // Write a JSON payload without fenHistory / finalFEN (both optional).
    const legacyJson = '{'
        '"id":"legacy-001",'
        '"timestamp":"2024-06-01T00:00:00.000",'
        '"gameType":"classic",'
        '"whiteLevel":"easy",'
        '"blackLevel":"easy",'
        '"result":"white",'
        '"resultReason":"checkmate",'
        '"moveLog":["e2e4","e7e5"],'
        '"totalMoves":2'
        '}';
    final db = svc.database;
    await db.insert('games', {
      'id': 'legacy-001',
      'timestamp': '2024-06-01T00:00:00.000',
      'payload': legacyJson,
    });

    final loaded = await svc.loadGame('legacy-001');
    expect(loaded, isNotNull);
    expect(loaded!.id, 'legacy-001');
    expect(loaded.fenHistory, isNull);
    expect(loaded.finalFEN, isNull);
    await svc.close();
  });

  test('3. simulated migration updates schema_version in meta', () async {
    // Exercise the upgrade path by manually calling the internal helper exposed
    // for testing.
    final svc = SavedGamesLocal.forTesting(inMemory: true);
    await svc.init();
    expect(await svc.schemaVersion(), 1);

    await svc.simulateMigrationToVersion(2);
    expect(await svc.schemaVersion(), 2);
    await svc.close();
  });

  test('4. downMigrationBlocked is true (down-grades not supported)', () {
    expect(SavedGamesLocal.downMigrationBlocked, isTrue);
  });
}
