// Proof test for roadmap §0.6.bullet-4 — saved-games DB size cap constants.
//
// Verifies that SavedGamesLocal exposes the correct maxDbBytes / warnDbBytes
// constants and that dbFileSizeBytes() returns a non-negative value.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:chessrecast/services/saved_game.dart';
import 'package:chessrecast/services/saved_games_local.dart';

SavedGame _g(String id) => SavedGame(
  id: id, timestamp: DateTime(2024), gameType: 'standard',
  whiteLevel: 'easy', blackLevel: 'easy', result: '*',
  resultReason: '', moveLog: const [], totalMoves: 0,
  startingFEN: null, finalFEN: null, fenHistory: null,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmpDir;
  late SavedGamesLocal db;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('db_size_cap_');
    db = SavedGamesLocal.forTesting(inMemory: false, dbDir: tmpDir.path);
    await db.init();
  });

  tearDown(() async {
    await db.close();
    tmpDir.deleteSync(recursive: true);
  });

  test('1. maxDbBytes constant is 200 MB', () {
    expect(SavedGamesLocal.maxDbBytes, 200 * 1024 * 1024);
  });

  test('2. warnDbBytes constant is 160 MB', () {
    expect(SavedGamesLocal.warnDbBytes, 160 * 1024 * 1024);
  });

  test('3. maxTotalBytes constant is 250 MB', () {
    expect(SavedGamesLocal.maxTotalBytes, 250 * 1024 * 1024);
  });

  test('4. dbFileSizeBytes returns a positive value after a write', () async {
    await db.saveGame(_g('g1'));
    final size = await db.dbFileSizeBytes();
    expect(size, greaterThan(0));
    expect(size, lessThan(SavedGamesLocal.maxDbBytes));
  });

  test('5. dbFileSizeBytes returns 0 for in-memory database', () async {
    final memDb = SavedGamesLocal.forTesting(inMemory: true);
    await memDb.init();
    addTearDown(() => memDb.close());
    expect(await memDb.dbFileSizeBytes(), 0);
  });
}
