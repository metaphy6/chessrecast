// Proof test for roadmap §0.6.bullet-4 — transcript (saved-games) retention cap.
//
// Verifies that SavedGamesLocal exposes gameCount(), isNearTranscriptCap(),
// isAtTranscriptCap(), and evictOldestGames() correctly.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:chessrecast/services/saved_game.dart';
import 'package:chessrecast/services/saved_games_local.dart';

SavedGame _makeGame(String id, DateTime ts) => SavedGame(
  id: id,
  timestamp: ts,
  gameType: 'standard',
  whiteLevel: 'easy',
  blackLevel: 'easy',
  result: '1-0',
  resultReason: 'checkmate',
  moveLog: const [],
  totalMoves: 1,
  startingFEN: null,
  finalFEN: null,
  fenHistory: null,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmpDir;
  late SavedGamesLocal db;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('transcript_retention_');
    db = SavedGamesLocal.forTesting(inMemory: false, dbDir: tmpDir.path);
    await db.init();
  });

  tearDown(() async {
    await db.close();
    tmpDir.deleteSync(recursive: true);
  });

  test('1. maxGames constant is 500', () {
    expect(SavedGamesLocal.maxGames, 500);
  });

  test('2. warnGames constant is 400', () {
    expect(SavedGamesLocal.warnGames, 400);
  });

  test('3. isNearTranscriptCap returns false below warn level', () async {
    for (var i = 0; i < 10; i++) {
      await db.saveGame(_makeGame('g_$i', DateTime.now()));
    }
    expect(await db.isNearTranscriptCap(), isFalse);
  });

  test('4. isNearTranscriptCap returns true at warn level', () async {
    final base = DateTime(2020);
    for (var i = 0; i < SavedGamesLocal.warnGames; i++) {
      await db.saveGame(_makeGame('g_$i', base.add(Duration(seconds: i))));
    }
    expect(await db.isNearTranscriptCap(), isTrue);
    expect(await db.isAtTranscriptCap(), isFalse);
  });

  test('5. isAtTranscriptCap returns true at hard cap', () async {
    final base = DateTime(2020);
    for (var i = 0; i < SavedGamesLocal.maxGames; i++) {
      await db.saveGame(_makeGame('g_$i', base.add(Duration(seconds: i))));
    }
    expect(await db.isAtTranscriptCap(), isTrue);
  });

  test('6. evictOldestGames removes the N oldest by timestamp', () async {
    final base = DateTime(2020);
    for (var i = 0; i < 20; i++) {
      await db.saveGame(_makeGame('g_$i', base.add(Duration(seconds: i))));
    }
    final deleted = await db.evictOldestGames(5);
    expect(deleted, 5);
    expect(await db.gameCount(), 15);
    // The remaining games should be the newest 15.
    final games = await db.listGames();
    final ids = games.map((g) => g.id).toSet();
    // g_0 through g_4 should be gone (oldest).
    for (var i = 0; i < 5; i++) {
      expect(ids.contains('g_$i'), isFalse,
          reason: 'g_$i should have been evicted');
    }
  });

  test('7. evictOldestGames(0) is a no-op', () async {
    await db.saveGame(_makeGame('g_0', DateTime.now()));
    final deleted = await db.evictOldestGames(0);
    expect(deleted, 0);
    expect(await db.gameCount(), 1);
  });
}
