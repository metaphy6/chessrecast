import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'saved_game.dart';

/// SQLite-backed saved-games store.
///
/// Public API mirrors [SavedGamesService] so it can be swapped in transparently.
/// The database has two tables:
///
///   meta  (key TEXT PRIMARY KEY, value TEXT NOT NULL)
///   games (id TEXT PRIMARY KEY, timestamp TEXT NOT NULL, payload TEXT NOT NULL)
///
/// The `meta` table carries a single `schema_version` row (value='1').
/// The `games.payload` column stores the full [SavedGame.toJsonString()] blob.
class SavedGamesLocal {
  static const _dbName = 'saved_games.db';
  static const _schemaVersion = 1;

  /// Whether downgrades are supported.  Always false — forward-only policy.
  static const bool downMigrationBlocked = true;

  final bool _inMemory;
  final String? _dbDir; // override directory (for tests)
  Database? _db;
  bool _wasQuarantined = false;

  SavedGamesLocal._({bool inMemory = false, String? dbDir})
      : _inMemory = inMemory,
        _dbDir = dbDir;

  /// Production constructor — uses the app's documents directory.
  SavedGamesLocal() : _inMemory = false, _dbDir = null;

  /// Test constructor: allows in-memory or file-based with a custom directory.
  SavedGamesLocal.forTesting({required bool inMemory, String? dbDir})
      : _inMemory = inMemory,
        _dbDir = dbDir;

  /// True if the previous [openSafe] call had to quarantine a corrupt DB file.
  bool get dbWasQuarantined => _wasQuarantined;

  /// The underlying [Database] instance (exposed for test introspection only).
  Database get database {
    assert(_db != null, 'Call init() or openSafe() before accessing the database.');
    return _db!;
  }

  /// Open and migrate the database.  Must be called before any other method.
  Future<void> init() async {
    if (_db != null) return;
    final p = _inMemory ? inMemoryDatabasePath : await _dbPath();
    _db = await openDatabase(
      p,
      version: _schemaVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Open the database with corruption recovery.
  ///
  /// If opening fails with any exception (typically caused by a corrupt file),
  /// the file is renamed to `saved_games_quarantine_<timestamp>.db` and a fresh
  /// database is initialised at the same path.  [dbWasQuarantined] is set to
  /// true in that case.
  Future<void> openSafe() async {
    _wasQuarantined = false;
    if (_db != null) return;
    if (_inMemory) {
      await init();
      return;
    }
    final dbPath = await _dbPath();
    try {
      _db = await openDatabase(
        dbPath,
        version: _schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      // Smoke-test: query the meta table to confirm the DB is readable.
      await _db!.query('meta', limit: 1);
    } catch (e) {
      debugPrint('[SavedGamesLocal] DB corrupt ($e), quarantining $dbPath');
      await _db?.close();
      _db = null;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final quarantinePath = dbPath.replaceFirst(
        _dbName,
        'saved_games_quarantine_$ts.db',
      );
      try {
        await File(dbPath).rename(quarantinePath);
      } catch (_) {
        // If rename fails, just delete to allow fresh creation.
        await File(dbPath).delete();
      }
      _wasQuarantined = true;
      _db = await openDatabase(
        dbPath,
        version: _schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  /// Close the underlying database connection.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Persist [game], overwriting any existing record with the same [SavedGame.id].
  Future<void> saveGame(SavedGame game) async {
    await _db!.insert(
      'games',
      {
        'id': game.id,
        'timestamp': game.timestamp.toIso8601String(),
        'payload': game.toJsonString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('[SavedGamesLocal] saved ${game.id}');
  }

  /// Return all games ordered newest-first; malformed rows are silently dropped.
  Future<List<SavedGame>> listGames() async {
    final rows = await _db!.query(
      'games',
      orderBy: 'timestamp DESC',
    );
    final result = <SavedGame>[];
    for (final row in rows) {
      try {
        result.add(SavedGame.fromJsonString(row['payload'] as String));
      } catch (e) {
        debugPrint('[SavedGamesLocal] skipping malformed row ${row['id']}: $e');
      }
    }
    return result;
  }

  /// Load a single game by [id]; returns null if not found.
  Future<SavedGame?> loadGame(String id) async {
    final rows = await _db!.query('games', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    try {
      return SavedGame.fromJsonString(rows.first['payload'] as String);
    } catch (e) {
      debugPrint('[SavedGamesLocal] malformed payload for $id: $e');
      return null;
    }
  }

  /// Delete the game with [id].  No-ops if the game does not exist.
  Future<void> deleteGame(String id) async {
    await _db!.delete('games', where: 'id = ?', whereArgs: [id]);
    debugPrint('[SavedGamesLocal] deleted $id');
  }

  /// Delete every stored game.
  Future<void> deleteAll() async {
    await _db!.delete('games');
    debugPrint('[SavedGamesLocal] deleted all games');
  }

  /// Return the stored schema version from the meta table.
  Future<int> schemaVersion() async {
    final rows = await _db!.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['schema_version'],
    );
    if (rows.isEmpty) return 0;
    return int.tryParse(rows.first['value'] as String) ?? 0;
  }

  /// Test-only helper: update the stored schema_version without running real
  /// migrations (used to verify the version bookkeeping logic in isolation).
  Future<void> simulateMigrationToVersion(int version) async {
    await _db!.update(
      'meta',
      {'value': '$version'},
      where: 'key = ?',
      whereArgs: ['schema_version'],
    );
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Forward migrations go here in future versions.
    // All migrations are forward-only; down_migration_blocked = true.
    await db.update(
      'meta',
      {'value': '$newVersion'},
      where: 'key = ?',
      whereArgs: ['schema_version'],
    );
  }
}
