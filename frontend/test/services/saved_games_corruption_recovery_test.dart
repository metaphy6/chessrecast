/// Proof test for roadmap §0.2.bullet-3: corruption recovery.
///
/// Tests:
/// 1. openSafe() succeeds normally when the DB file is healthy.
/// 2. When the DB file contains random bytes (simulated corruption),
///    openSafe() moves the file to a quarantine path and returns a fresh DB.
/// 3. After quarantine the fresh DB has schema_version = 1 and listGames = [].
/// 4. dbWasQuarantined returns true after a corrupt open.
/// 5. dbWasQuarantined returns false after a clean open.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/services/saved_games_local.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('1. openSafe on a healthy DB works normally', () async {
    final dir = Directory.systemTemp.createTempSync('sglocal_healthy_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dir.path);
    await svc.openSafe();

    expect(svc.dbWasQuarantined, isFalse);
    expect(await svc.schemaVersion(), 1);
    await svc.close();
  });

  test('2. openSafe on a corrupt file quarantines it', () async {
    final dir = Directory.systemTemp.createTempSync('sglocal_corrupt_');
    addTearDown(() => dir.deleteSync(recursive: true));

    // Write garbage bytes where the DB file would live.
    final dbFile = File(p.join(dir.path, 'saved_games.db'));
    dbFile.writeAsBytesSync(List.filled(64, 0xDE)); // obviously not SQLite

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dir.path);
    await svc.openSafe();

    expect(svc.dbWasQuarantined, isTrue);

    // The quarantine file must exist in the same directory.
    final quarantined = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('saved_games_quarantine_'))
        .toList();
    expect(quarantined, isNotEmpty, reason: 'Quarantine file must be created');
    await svc.close();
  });

  test('3. fresh DB after quarantine is empty and version=1', () async {
    final dir = Directory.systemTemp.createTempSync('sglocal_fresh_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final dbFile = File(p.join(dir.path, 'saved_games.db'));
    dbFile.writeAsBytesSync(List.filled(64, 0xFF));

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dir.path);
    await svc.openSafe();

    expect(await svc.listGames(), isEmpty);
    expect(await svc.schemaVersion(), 1);
    await svc.close();
  });

  test('4. dbWasQuarantined is true after corrupt open', () async {
    final dir = Directory.systemTemp.createTempSync('sglocal_q4_');
    addTearDown(() => dir.deleteSync(recursive: true));

    File(p.join(dir.path, 'saved_games.db'))
        .writeAsBytesSync(List.filled(32, 0xAA));

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dir.path);
    await svc.openSafe();
    expect(svc.dbWasQuarantined, isTrue);
    await svc.close();
  });

  test('5. dbWasQuarantined is false after clean open', () async {
    final dir = Directory.systemTemp.createTempSync('sglocal_q5_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final svc = SavedGamesLocal.forTesting(inMemory: false, dbDir: dir.path);
    await svc.openSafe();
    expect(svc.dbWasQuarantined, isFalse);
    await svc.close();
  });
}
