import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

  // ---------------------------------------------------------------------------
  // Retention-policy constants (roadmap §0.6.bullet-4)
  // ---------------------------------------------------------------------------

  /// Maximum number of saved games before hard enforcement (transcript cap).
  static const int maxGames = 500;

  /// Warn level for the transcript cap.
  static const int warnGames = 400;

  /// Hard cap on the SQLite database file size in bytes (200 MB).
  static const int maxDbBytes = 200 * 1024 * 1024;

  /// Warn level for the database file size.
  static const int warnDbBytes = 160 * 1024 * 1024;

  /// Hard ceiling on total P2P-owned bytes in the documents directory (250 MB).
  static const int maxTotalBytes = 250 * 1024 * 1024;

  /// Whether downgrades are supported.  Always false — forward-only policy.
  static const bool downMigrationBlocked = true;

  final bool _inMemory;
  final String? _dbDir; // override directory (for tests)
  Database? _db;
  bool _wasQuarantined = false;
  bool _dbWasFromDifferentInstall = false;
  String?
  _currentInstallId; // set during init/openSafe; written to meta on creation
  // Warm-path cache — invalidated on every write so it is always consistent.
  List<SavedGame>? _listCache;

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

  /// True if the DB that was opened on [openSafe] was created by a different
  /// app installation (i.e. its stored `install_id` differs from the one
  /// generated for this install session).  Consumers should surface a warning.
  bool get dbWasFromDifferentInstall => _dbWasFromDifferentInstall;

  /// The install-scoped UUID for this database session (set after [init] or
  /// [openSafe]).  Null before opening.
  String? get installId => _currentInstallId;

  /// The underlying [Database] instance (exposed for test introspection only).
  Database get database {
    assert(
      _db != null,
      'Call init() or openSafe() before accessing the database.',
    );
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
    // For in-memory DBs there is no marker file; use a simple generated ID.
    if (_inMemory) {
      _currentInstallId = await _loadOrCreateInstallId();
    } else {
      final markerInstallId = await _loadOrCreateInstallMarker();
      _currentInstallId = await _loadOrCreateInstallId(
        fallback: markerInstallId,
      );
    }
  }

  /// Open the database with corruption recovery.
  ///
  /// If opening fails with any exception (typically caused by a corrupt file),
  /// the file is renamed to `saved_games_quarantine_<timestamp>.db` and a fresh
  /// database is initialised at the same path.  [dbWasQuarantined] is set to
  /// true in that case.
  ///
  /// Sets [dbWasFromDifferentInstall] to true if the DB was created by a
  /// different app installation (detected via the `install_id` meta row
  /// compared against a per-install marker file stored next to the DB).
  Future<void> openSafe() async {
    _wasQuarantined = false;
    _dbWasFromDifferentInstall = false;
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
      // Cross-install detection: compare the DB's stored install_id against
      // the per-install marker file stored next to the DB.
      final markerInstallId = await _loadOrCreateInstallMarker();
      _currentInstallId = await _loadOrCreateInstallId(
        fallback: markerInstallId,
      );
      if (_currentInstallId != markerInstallId) {
        _dbWasFromDifferentInstall = true;
        debugPrint(
          '[SavedGamesLocal] cross-install restore detected: '
          'db_install_id=$_currentInstallId marker_id=$markerInstallId',
        );
      }
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
      final markerIdAfterQuarantine = await _loadOrCreateInstallMarker();
      _currentInstallId = await _loadOrCreateInstallId(
        fallback: markerIdAfterQuarantine,
      );
    }
  }

  /// Close the underlying database connection.
  Future<void> close() async {
    _listCache = null;
    await _db?.close();
    _db = null;
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Persist [game], overwriting any existing record with the same [SavedGame.id].
  Future<void> saveGame(SavedGame game) async {
    _listCache = null;
    await _db!.insert('games', {
      'id': game.id,
      'timestamp': game.timestamp.toIso8601String(),
      'payload': game.toJsonString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint('[SavedGamesLocal] saved ${game.id}');
  }

  /// Return all games ordered newest-first; malformed rows are silently dropped.
  ///
  /// Performance: warm calls return a cached [List] populated by the previous
  /// call; the cache is invalidated on every [saveGame], [deleteGame], or
  /// [deleteAll].  Cold calls use SQLite's json_extract() C function to retrieve
  /// only the summary fields — avoids decoding the full payload in Dart.
  /// The [moveLog] and [fenHistory] fields are empty/null on returned objects;
  /// call [loadGame] for the full record.
  Future<List<SavedGame>> listGames() async {
    if (_listCache != null) return List.unmodifiable(_listCache!);
    _listCache = await _fetchListGames();
    return List.unmodifiable(_listCache!);
  }

  Future<List<SavedGame>> _fetchListGames() async {
    final rows = await _db!.rawQuery('''
      SELECT
        id,
        timestamp,
        json_extract(payload, '\$.gameType')     AS gameType,
        json_extract(payload, '\$.whiteLevel')   AS whiteLevel,
        json_extract(payload, '\$.blackLevel')   AS blackLevel,
        json_extract(payload, '\$.result')       AS result,
        json_extract(payload, '\$.resultReason') AS resultReason,
        json_extract(payload, '\$.totalMoves')   AS totalMoves,
        json_extract(payload, '\$.startingFEN')  AS startingFEN,
        json_extract(payload, '\$.finalFEN')     AS finalFEN
      FROM games
      WHERE json_valid(payload) = 1
      ORDER BY timestamp DESC
    ''');
    final result = <SavedGame>[];
    for (final row in rows) {
      final id = row['id'] as String;
      // json_extract returns NULL for any key when the payload is corrupt.
      final gameType = row['gameType'] as String?;
      if (gameType == null) {
        debugPrint(
          '[SavedGamesLocal] skipping malformed row $id: json_extract returned null',
        );
        continue;
      }
      try {
        result.add(
          SavedGame(
            id: id,
            timestamp: DateTime.parse(row['timestamp'] as String),
            gameType: gameType,
            whiteLevel: row['whiteLevel'] as String? ?? '',
            blackLevel: row['blackLevel'] as String? ?? '',
            result: row['result'] as String? ?? '',
            resultReason: row['resultReason'] as String? ?? '',
            moveLog: const [],
            totalMoves: row['totalMoves'] as int? ?? 0,
            startingFEN: row['startingFEN'] as String?,
            finalFEN: row['finalFEN'] as String?,
            fenHistory: null,
          ),
        );
      } catch (e) {
        debugPrint('[SavedGamesLocal] skipping malformed row $id: $e');
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
    _listCache = null;
    await _db!.delete('games', where: 'id = ?', whereArgs: [id]);
    debugPrint('[SavedGamesLocal] deleted $id');
  }

  /// Delete every stored game.
  Future<void> deleteAll() async {
    _listCache = null;
    await _db!.delete('games');
    debugPrint('[SavedGamesLocal] deleted all games');
  }

  // ---------------------------------------------------------------------------
  // Retention policy (roadmap §0.6.bullet-4)
  // ---------------------------------------------------------------------------

  /// Return the current number of stored games.
  Future<int> gameCount() async {
    final result = await _db!.rawQuery('SELECT COUNT(*) AS cnt FROM games');
    return result.first['cnt'] as int? ?? 0;
  }

  /// Whether the game count is approaching [maxGames].
  Future<bool> isNearTranscriptCap() async => await gameCount() >= warnGames;

  /// Whether the game count has hit or exceeded [maxGames].
  Future<bool> isAtTranscriptCap() async => await gameCount() >= maxGames;

  /// Evict the [count] oldest games (by timestamp).
  ///
  /// Returns the number of rows actually deleted.
  Future<int> evictOldestGames(int count) async {
    if (count <= 0) return 0;
    _listCache = null;
    final deleted = await _db!.rawDelete(
      '''
      DELETE FROM games
      WHERE id IN (
        SELECT id FROM games ORDER BY timestamp ASC LIMIT ?
      )
    ''',
      [count],
    );
    debugPrint('[SavedGamesLocal] evicted $deleted oldest games');
    return deleted;
  }

  /// Return the size of the on-disk SQLite database file, or 0 for in-memory.
  Future<int> dbFileSizeBytes() async {
    if (_inMemory) return 0;
    final p = await _dbPath();
    final f = File(p);
    return f.existsSync() ? f.lengthSync() : 0;
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
  // Legacy JSON-on-disk migration
  // ---------------------------------------------------------------------------

  /// Whether the one-time legacy-format migration has been completed.
  ///
  /// Returns true once [migrateFromLegacyJsonDirectory] has finished without
  /// error at least once.
  Future<bool> legacyMigrated() async {
    final rows = await _db!.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['legacy_migrated'],
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  /// Import games from the legacy [SavedGamesService] JSON-on-disk format.
  ///
  /// [jsonDir] is the `saved_games/` directory that contained one `.json` file
  /// per game.  Corrupt / unparseable files are silently skipped.
  ///
  /// The method is idempotent: games whose [SavedGame.id] already exists in
  /// the SQLite store are not re-imported (CONFLICT IGNORE).
  ///
  /// Sets the `legacy_migrated` meta key to `'1'` after a complete run
  /// (all files processed, regardless of how many were corrupt).
  ///
  /// Returns the number of games that were newly imported.
  Future<int> migrateFromLegacyJsonDirectory(Directory jsonDir) async {
    if (!jsonDir.existsSync()) {
      await _markLegacyMigrated();
      return 0;
    }

    final jsonFiles = jsonDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    int imported = 0;
    for (final file in jsonFiles) {
      String content;
      try {
        content = await file.readAsString();
      } catch (e) {
        debugPrint('[SavedGamesLocal] migration: cannot read ${file.path}: $e');
        continue;
      }
      SavedGame game;
      try {
        game = SavedGame.fromJsonString(content);
      } catch (e) {
        debugPrint(
          '[SavedGamesLocal] migration: skipping malformed ${file.path}: $e',
        );
        continue;
      }
      final rows = await _db!.insert('games', {
        'id': game.id,
        'timestamp': game.timestamp.toIso8601String(),
        'payload': game.toJsonString(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (rows > 0) {
        _listCache = null;
        imported++;
      }
    }

    await _markLegacyMigrated();
    return imported;
  }

  Future<void> _markLegacyMigrated() async {
    await _db!.insert('meta', {
      'key': 'legacy_migrated',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<String> _dbPath() async {
    if (_dbDir != null) return path_pkg.join(_dbDir!, _dbName);
    final dir = await getApplicationDocumentsDirectory();
    return path_pkg.join(dir.path, _dbName);
  }

  /// Path of the per-install marker file (stored next to the DB, not inside it).
  Future<String> _markerPath() async {
    if (_dbDir != null) {
      return path_pkg.join(_dbDir!, '.install_marker');
    }
    final dir = await getApplicationDocumentsDirectory();
    return path_pkg.join(dir.path, '.install_marker');
  }

  /// Load the install_id from the per-install marker file, or generate and
  /// persist one if the file does not exist yet.
  Future<String> _loadOrCreateInstallMarker() async {
    final path = await _markerPath();
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsStringSync().trim();
    }
    final newId = _generateInstallId();
    file.writeAsStringSync(newId);
    return newId;
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

  // ---------------------------------------------------------------------------
  // Install-ID helpers (cross-install restore detection, roadmap §0.6.bullet-5)
  // ---------------------------------------------------------------------------

  /// Load the `install_id` from the meta table, or generate and persist one if
  /// it does not exist yet.  If [fallback] is provided it is used as the new ID
  /// (so the DB and the marker file share the same UUID on first creation).
  Future<String> _loadOrCreateInstallId({String? fallback}) async {
    final rows = await _db!.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['install_id'],
    );
    if (rows.isNotEmpty) {
      return rows.first['value'] as String;
    }
    final newId = fallback ?? _generateInstallId();
    await _db!.insert('meta', {
      'key': 'install_id',
      'value': newId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return newId;
  }

  /// Generate a random UUID v4 using `dart:math` (no external dependency).
  static String _generateInstallId() {
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }
}
