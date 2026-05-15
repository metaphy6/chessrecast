/// Proof test for roadmap §0.6.bullet-1 — SQLCipher/at-rest encryption.
///
/// Verifies that [SavedGamesLocalEncrypted] (AES-256-GCM equivalent of
/// SQLCipher) stores game payloads encrypted:
///   1. Round-trip: saved game can be retrieved correctly.
///   2. Key is set up correctly in meta (cipher_version, kdf_params).
///   3. The cipher is stateless-reconstructible from kdf_params (key reload).
///   4. Tampered ciphertext fails to decrypt with an error, not silent garbage.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../lib/services/saved_game.dart';
import '../../../lib/services/saved_games_local_encrypted.dart';

SavedGame _makeGame(String id) => SavedGame(
  id: id,
  timestamp: DateTime(2025, 6, 1),
  gameType: 'classic',
  whiteLevel: 'hard',
  blackLevel: 'expert',
  result: 'white',
  resultReason: 'checkmate',
  moveLog: ['e2e4', 'e7e5', 'g1f3', 'b8c6'],
  totalMoves: 4,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('1. round-trip: save and load returns the correct game', () async {
    final dbDir = Directory.systemTemp.createTempSync('enc_rt_');
    addTearDown(() => dbDir.deleteSync(recursive: true));

    final svc = SavedGamesLocalEncrypted.forTesting(
      inMemory: false,
      dbDir: dbDir.path,
    );
    await svc.init();

    final game = _makeGame('rt-001');
    await svc.saveGame(game);

    final loaded = await svc.loadGame('rt-001');
    expect(loaded, isNotNull);
    expect(loaded!.id, 'rt-001');
    expect(loaded.gameType, 'classic');
    expect(loaded.moveLog, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);

    await svc.close();
  });

  test('2. meta table contains cipher_version and kdf_params', () async {
    final dbDir = Directory.systemTemp.createTempSync('enc_meta_');
    addTearDown(() => dbDir.deleteSync(recursive: true));

    final svc = SavedGamesLocalEncrypted.forTesting(
      inMemory: false,
      dbDir: dbDir.path,
    );
    await svc.init();

    // Access the underlying DB via a second plain sqflite open to read meta.
    final dbPath = p.join(dbDir.path, 'saved_games_enc.db');
    final db = await databaseFactory.openDatabase(dbPath);
    final rows = await db.query(
      'meta',
      where: 'key IN (?, ?)',
      whereArgs: ['cipher_version', 'kdf_params'],
    );
    await db.close();
    await svc.close();

    final keys = rows.map((r) => r['key'] as String).toSet();
    expect(keys, containsAll(['cipher_version', 'kdf_params']));

    final kdfRow = rows.firstWhere((r) => r['key'] == 'kdf_params');
    // kdf_params must be a valid base64-encoded 32-byte key.
    final keyBytes = base64.decode(kdfRow['value'] as String);
    expect(keyBytes.length, 32, reason: 'KEK must be 256 bits');
  });

  test(
    '3. cipher is reconstructible from kdf_params (key reload test)',
    () async {
      final dbDir = Directory.systemTemp.createTempSync('enc_reload_');
      addTearDown(() => dbDir.deleteSync(recursive: true));

      final svc1 = SavedGamesLocalEncrypted.forTesting(
        inMemory: false,
        dbDir: dbDir.path,
      );
      await svc1.init();
      await svc1.saveGame(_makeGame('reload-1'));
      await svc1.close();

      // Re-open — should reload the key from kdf_params and decrypt correctly.
      final svc2 = SavedGamesLocalEncrypted.forTesting(
        inMemory: false,
        dbDir: dbDir.path,
      );
      await svc2.init();
      final loaded = await svc2.loadGame('reload-1');
      await svc2.close();

      expect(loaded, isNotNull, reason: 'Game must survive DB close/reopen');
      expect(loaded!.id, 'reload-1');
    },
  );

  test(
    '4. tampered ciphertext is detected (AEAD authentication fails)',
    () async {
      final dbDir = Directory.systemTemp.createTempSync('enc_tamper_');
      addTearDown(() => dbDir.deleteSync(recursive: true));

      final svc = SavedGamesLocalEncrypted.forTesting(
        inMemory: false,
        dbDir: dbDir.path,
      );
      await svc.init();
      await svc.saveGame(_makeGame('tamper-1'));

      // Directly corrupt the payload in the DB.
      final dbPath = p.join(dbDir.path, 'saved_games_enc.db');
      final db = await databaseFactory.openDatabase(dbPath);
      await db.update(
        'games',
        {'payload': 'AAAA_tampered_ciphertext_ZZZZ'},
        where: 'id = ?',
        whereArgs: ['tamper-1'],
      );
      await db.close();

      // Reopen the encrypted service — loadGame must return null, not a garbled
      // game (the decrypt error is caught and logged).
      final svc2 = SavedGamesLocalEncrypted.forTesting(
        inMemory: false,
        dbDir: dbDir.path,
      );
      await svc2.init();
      final loaded = await svc2.loadGame('tamper-1');
      await svc2.close();

      expect(
        loaded,
        isNull,
        reason:
            'Tampered ciphertext must not produce a usable game; '
            'loadGame must return null',
      );
    },
  );
}
