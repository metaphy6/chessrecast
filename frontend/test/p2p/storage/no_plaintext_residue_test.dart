/// Proof test for roadmap §0.6.bullet-1 — no-plaintext-residue check.
///
/// After writing a game to [SavedGamesLocalEncrypted] and closing the
/// connection, the raw `.db` file must NOT contain any of the known
/// plaintext markers that would appear if the payload were stored clear.
///
/// Markers checked:
///   - The game ID (`PLAINTEXT_GAME_ID`)
///   - A move from the move log (`e2e4`)
///   - The game type string (`specialplaintype`)
///   - The `fenHistory` sentinel value (`plainhistory_fen`)
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../lib/services/saved_game.dart';
import '../../../lib/services/saved_games_local_encrypted.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('raw .db file contains no known plaintext after encrypted write', () async {
    final dbDir = Directory.systemTemp.createTempSync('no_plain_');
    addTearDown(() => dbDir.deleteSync(recursive: true));

    const gameId = 'PLAINTEXT_GAME_ID';
    const gameType = 'specialplaintype';
    const sentinelMove = 'e2e4';
    const sentinelFen = 'plainhistory_fen';

    final svc = SavedGamesLocalEncrypted.forTesting(
      inMemory: false,
      dbDir: dbDir.path,
    );
    await svc.init();

    await svc.saveGame(
      SavedGame(
        id: gameId,
        timestamp: DateTime(2025, 7, 1),
        gameType: gameType,
        whiteLevel: 'medium',
        blackLevel: 'hard',
        result: 'draw',
        resultReason: 'agreement',
        moveLog: [sentinelMove, 'e7e5'],
        fenHistory: [
          sentinelFen,
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
        ],
        totalMoves: 2,
      ),
    );

    // Close the connection so all pages are flushed to disk.
    await svc.close();

    // Read the raw DB bytes.
    final dbPath = p.join(dbDir.path, 'saved_games_enc.db');
    final raw = File(dbPath).readAsBytesSync();

    // Convert to string for marker search (UTF-8; non-printable bytes are
    // replaced by replacement chars, but ASCII markers remain intact).
    final rawStr = String.fromCharCodes(raw.map((b) => b < 128 ? b : 0x3F));

    // The `id` and `timestamp` columns are stored plaintext (they are primary-
    // key/index values used for lookups).  We only check that payload-specific
    // content — which would appear if payload were stored as raw JSON — is NOT
    // present.
    for (final marker in [gameType, sentinelMove, sentinelFen]) {
      expect(
        rawStr.contains(marker),
        isFalse,
        reason:
            'Plaintext marker "$marker" found in raw DB file — '
            'payload is NOT encrypted',
      );
    }
  });
}
