// Proof test for roadmap §0.6.bullet-5 — cross-install restore detection.
//
// Verifies that SavedGamesLocal.openSafe() sets dbWasFromDifferentInstall=true
// when a DB whose stored install_id differs from the per-install marker file
// is opened (simulating an iOS/Android cloud-backup restore onto a new device).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:chessrecast/services/saved_games_local.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('1. install_id is written to meta on first init', () async {
    final tmp = Directory.systemTemp.createTempSync('ci_restore_1_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final db = SavedGamesLocal.forTesting(inMemory: false, dbDir: tmp.path);
    await db.init();
    addTearDown(() => db.close());
    expect(db.installId, isNotNull);
    expect(db.installId, isNotEmpty);
  });

  test('2. same install reopens without cross-install flag', () async {
    final tmp = Directory.systemTemp.createTempSync('ci_restore_2_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    // First open creates the DB + marker file.
    final db1 = SavedGamesLocal.forTesting(inMemory: false, dbDir: tmp.path);
    await db1.openSafe();
    addTearDown(() => db1.close());
    expect(db1.dbWasFromDifferentInstall, isFalse);
  });

  test('3. cross-install restore detected when marker differs from DB install_id',
      () async {
    final original = Directory.systemTemp.createTempSync('ci_orig_');
    final restored = Directory.systemTemp.createTempSync('ci_rest_');
    addTearDown(() {
      original.deleteSync(recursive: true);
      restored.deleteSync(recursive: true);
    });

    // 1. Create a DB in 'original' with openSafe() — writes install_id to meta
    //    AND creates the .install_marker file.
    final db1 = SavedGamesLocal.forTesting(inMemory: false, dbDir: original.path);
    await db1.openSafe();
    final origInstallId = db1.installId;
    await db1.close();

    // 2. Copy only the DB file to 'restored' (simulating a cloud-backup restore
    //    onto a new device that does NOT have the .install_marker file).
    final origDbPath = '${original.path}/saved_games.db';
    final restDbPath = '${restored.path}/saved_games.db';
    File(origDbPath).copySync(restDbPath);
    // Do NOT copy .install_marker — the new device will generate its own.

    // 3. Open on the 'new device' with openSafe().
    final db2 = SavedGamesLocal.forTesting(inMemory: false, dbDir: restored.path);
    await db2.openSafe();
    addTearDown(() => db2.close());

    // The DB carries the original install_id; the new marker is different.
    expect(db2.installId, equals(origInstallId));
    expect(db2.dbWasFromDifferentInstall, isTrue);
  });

  test('4. install_id is stable across repeated opens of the same DB', () async {
    final tmp = Directory.systemTemp.createTempSync('ci_stable_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final db1 = SavedGamesLocal.forTesting(inMemory: false, dbDir: tmp.path);
    await db1.init();
    final id1 = db1.installId;
    await db1.close();
    final db2 = SavedGamesLocal.forTesting(inMemory: false, dbDir: tmp.path);
    await db2.init();
    final id2 = db2.installId;
    await db2.close();
    expect(id1, equals(id2));
  });
}
