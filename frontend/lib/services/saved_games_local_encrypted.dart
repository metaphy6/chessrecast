/// AES-256-GCM encrypted variant of [SavedGamesLocal].
///
/// Identical public API; the `payload` column in the `games` table stores
/// the base64url-encoded ciphertext returned by [AtRestCipher.encryptPayload]
/// instead of raw JSON.
///
/// The `meta` table gains two additional rows:
///   cipher_version  INTEGER  (currently always "1")
///   kdf_params      TEXT     (base64-encoded 256-bit KEK — Phase 2.1 will
///                             replace this with a device-key-wrapped blob)
///
/// On first [init] call the KEK is generated at random and stored.  All
/// subsequent opens reload it from the meta table and reconstruct the cipher.
///
/// [listGames] falls back to full Dart-layer decryption (no json_extract on
/// ciphertext), but the warm-path cache means this overhead is paid at most
/// once per session.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'at_rest_cipher.dart';
import 'saved_game.dart';

class SavedGamesLocalEncrypted {
  static const _dbName = 'saved_games_enc.db';
  static const _schemaVersion = 1;

  final bool _inMemory;
  final String? _dbDir;

  Database? _db;
  AtRestCipher? _cipher;
  List<SavedGame>? _listCache;

  /// Production constructor — uses the app's documents directory.
  SavedGamesLocalEncrypted() : _inMemory = false, _dbDir = null;

  /// Test constructor.
  SavedGamesLocalEncrypted.forTesting({required bool inMemory, String? dbDir})
      : _inMemory = inMemory,
        _dbDir = dbDir;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    if (_db != null) return;
    final p = _inMemory ? inMemoryDatabasePath : await _dbPath();
    _db = await openDatabase(
      p,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: (db, oldV, newV) async {},
    );
    await _loadOrCreateCipher();
  }

  Future<void> close() async {
    _listCache = null;
    _cipher = null;
    await _db?.close();
    _db = null;
  }

  // ---------------------------------------------------------------------------
  // Public API (mirrors SavedGamesLocal)
  // ---------------------------------------------------------------------------

  Future<void> saveGame(SavedGame game) async {
    _listCache = null;
    final ciphertext = _cipher!.encryptPayload(game.toJsonString());
    await _db!.insert(
      'games',
      {
        'id': game.id,
        'timestamp': game.timestamp.toIso8601String(),
        'payload': ciphertext,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple games in a single transaction — much faster than calling
  /// [saveGame] in a loop for bulk-import or test setup.
  Future<void> batchSave(List<SavedGame> games) async {
    if (games.isEmpty) return;
    _listCache = null;
    await _db!.transaction((txn) async {
      for (final game in games) {
        final ciphertext = _cipher!.encryptPayload(game.toJsonString());
        await txn.insert(
          'games',
          {
            'id': game.id,
            'timestamp': game.timestamp.toIso8601String(),
            'payload': ciphertext,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<SavedGame>> listGames() async {
    if (_listCache != null) return List.unmodifiable(_listCache!);
    _listCache = await _fetchListGames();
    return List.unmodifiable(_listCache!);
  }

  Future<SavedGame?> loadGame(String id) async {
    final rows = await _db!.query('games', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    try {
      final plaintext = _cipher!.decryptPayload(rows.first['payload'] as String);
      return SavedGame.fromJsonString(plaintext);
    } catch (e) {
      debugPrint('[SavedGamesLocalEncrypted] failed to decrypt $id: $e');
      return null;
    }
  }

  Future<void> deleteGame(String id) async {
    _listCache = null;
    await _db!.delete('games', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    _listCache = null;
    await _db!.delete('games');
  }

  Future<int> gameCount() async {
    final result = await _db!.rawQuery('SELECT COUNT(*) as c FROM games');
    return (result.first['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String> _dbPath() async {
    if (_dbDir != null) return path_pkg.join(_dbDir!, _dbName);
    final dir = await getApplicationDocumentsDirectory();
    return path_pkg.join(dir.path, _dbName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE meta (
        key   TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE games (
        id        TEXT PRIMARY KEY NOT NULL,
        timestamp TEXT NOT NULL,
        payload   TEXT NOT NULL
      )
    ''');
    await db.insert('meta', {'key': 'schema_version', 'value': '$version'});
  }

  Future<void> _loadOrCreateCipher() async {
    final rows = await _db!.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['kdf_params'],
    );
    if (rows.isEmpty) {
      // First-time setup: generate a random KEK and persist it.
      final cipher = AtRestCipher.generate();
      await _db!.insert(
        'meta',
        {'key': 'cipher_version', 'value': '${AtRestCipher.cipherVersion}'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _db!.insert(
        'meta',
        {'key': 'kdf_params', 'value': cipher.exportKeyBase64()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _cipher = cipher;
    } else {
      // Reload existing KEK from the meta table.
      // If the stored value is corrupt (e.g. truncated or tampered), this must
      // raise rather than silently creating a new DB — per roadmap §0.6 quality
      // requirement ("SQLCIPHER_KEY_UNWRAP_FAIL").
      try {
        _cipher = AtRestCipher.fromBase64(rows.first['value'] as String);
      } catch (e) {
        throw StateError(
          'SQLCIPHER_KEY_UNWRAP_FAIL: stored kdf_params is corrupt or '
          'unreadable ($e). Refusing to open without a valid KEK.',
        );
      }
    }
  }

  Future<List<SavedGame>> _fetchListGames() async {
    final rows = await _db!.query(
      'games',
      columns: ['id', 'timestamp', 'payload'],
      orderBy: 'timestamp DESC',
    );
    final result = <SavedGame>[];
    for (final row in rows) {
      final id = row['id'] as String;
      try {
        final plaintext = _cipher!.decryptPayload(row['payload'] as String);
        final game = SavedGame.fromJsonString(plaintext);
        result.add(SavedGame(
          id: game.id,
          timestamp: game.timestamp,
          gameType: game.gameType,
          whiteLevel: game.whiteLevel,
          blackLevel: game.blackLevel,
          result: game.result,
          resultReason: game.resultReason,
          moveLog: const [],
          totalMoves: game.totalMoves,
          startingFEN: game.startingFEN,
          finalFEN: game.finalFEN,
          fenHistory: null,
        ));
      } catch (e) {
        debugPrint('[SavedGamesLocalEncrypted] skipping malformed row $id: $e');
      }
    }
    return result;
  }
}
