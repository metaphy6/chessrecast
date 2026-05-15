/// Proof test for roadmap §0.4.bullet-1 — Performance.
///
/// Verifies that [SavedGamesLocal.listGames] serves 1,000 stored games in:
///   • cold path (first call after DB open): < 50 ms
///   • warm path (second call, in-process):  < 10 ms
///
/// A "realistic" game payload includes a 40-ply fenHistory so the payload size
/// approximates a real game (~4–6 KB per row).  The bottleneck on the old
/// implementation was Dart-side JSON decoding of every payload.  The fix uses
/// SQLite's json_extract() C function to retrieve only summary fields, avoiding
/// full Dart JSON parsing on the list path.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/services/saved_game.dart';
import '../../lib/services/saved_games_local.dart';

/// Build a game with a realistic payload (40-ply fenHistory, 40 moveLog entries).
SavedGame _makeRealisticGame(int index) {
  const startingFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  // 40 plies of fake (but non-trivial length) FEN strings
  final fenHistory = List<String>.generate(
    40,
    (i) => 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 ${i + 1}',
  );
  final moveLog = List<String>.generate(40, (i) => 'e2e4');
  return SavedGame(
    id: 'perf-game-$index',
    timestamp: DateTime(2025, 1, 1).add(Duration(seconds: index)),
    gameType: 'classic',
    whiteLevel: 'hard',
    blackLevel: 'medium',
    result: index.isEven ? 'white' : 'black',
    resultReason: 'checkmate',
    moveLog: moveLog,
    startingFEN: startingFen,
    finalFEN: fenHistory.last,
    fenHistory: fenHistory,
    totalMoves: 40,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('cold list 1000 games < 50 ms; warm list < 10 ms', () async {
    // Use a real file-based DB for a meaningful cold measurement.
    final tempDir = await Directory.systemTemp.createTemp('perf_test_');
    addTearDown(() => tempDir.delete(recursive: true));

    // ── Seed phase ──────────────────────────────────────────────────────────
    final seed = SavedGamesLocal.forTesting(
      inMemory: false,
      dbDir: tempDir.path,
    );
    await seed.init();
    for (var i = 0; i < 1000; i++) {
      await seed.saveGame(_makeRealisticGame(i));
    }
    await seed.close();

    // ── Cold measurement ─────────────────────────────────────────────────────
    // Open a fresh instance so the DB page cache is cold.
    final cold = SavedGamesLocal.forTesting(
      inMemory: false,
      dbDir: tempDir.path,
    );
    await cold.init();

    final sw1 = Stopwatch()..start();
    final coldList = await cold.listGames();
    sw1.stop();

    expect(coldList.length, 1000, reason: 'Should return all 1000 games');
    expect(
      sw1.elapsedMilliseconds,
      lessThan(50),
      reason:
          'Cold list must complete in < 50 ms (got ${sw1.elapsedMilliseconds} ms)',
    );

    // ── Warm measurement ─────────────────────────────────────────────────────
    final sw2 = Stopwatch()..start();
    final warmList = await cold.listGames();
    sw2.stop();

    expect(warmList.length, 1000);
    expect(
      sw2.elapsedMilliseconds,
      lessThan(10),
      reason:
          'Warm list must complete in < 10 ms (got ${sw2.elapsedMilliseconds} ms)',
    );

    await cold.close();
  });
}
