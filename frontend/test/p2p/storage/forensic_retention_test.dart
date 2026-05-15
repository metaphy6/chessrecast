// Proof test for roadmap §0.6.bullet-4 — forensic-bundle FIFO retention cap.
//
// Verifies that ForensicStore.enforceRetentionPolicy() evicts the oldest
// bundles when the session count exceeds ForensicStore.maxBundles (50).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/forensic_store.dart';

void main() {
  late Directory tmpDir;
  late ForensicStore store;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('forensic_retention_');
    store = ForensicStore(docsDir: tmpDir.path);
    await store.init();
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('1. No eviction when bundle count <= maxBundles', () async {
    for (var i = 0; i < ForensicStore.maxBundles; i++) {
      await store.writeBundle(
        sessionId: 'session_$i',
        payload: Uint8List.fromList('payload_$i'.codeUnits),
      );
    }
    final evicted = await store.enforceRetentionPolicy();
    expect(evicted, 0);
    expect(store.listSessions().length, ForensicStore.maxBundles);
  });

  test('2. Oldest sessions evicted when count exceeds maxBundles', () async {
    // Write maxBundles + 5 sessions.
    final total = ForensicStore.maxBundles + 5;
    for (var i = 0; i < total; i++) {
      // Small sleep ensures mtime ordering is deterministic.
      await Future.delayed(const Duration(milliseconds: 1));
      await store.writeBundle(
        sessionId: 'session_${i.toString().padLeft(4, '0')}',
        payload: Uint8List.fromList('payload_$i'.codeUnits),
      );
    }
    final evicted = await store.enforceRetentionPolicy();
    expect(evicted, 5);
    expect(store.listSessions().length, ForensicStore.maxBundles);
  });

  test('3. Newest sessions survive after eviction', () async {
    final total = ForensicStore.maxBundles + 3;
    final sessionIds = <String>[];
    for (var i = 0; i < total; i++) {
      await Future.delayed(const Duration(milliseconds: 1));
      final id = 'session_${i.toString().padLeft(4, '0')}';
      sessionIds.add(id);
      await store.writeBundle(
        sessionId: id,
        payload: Uint8List.fromList('data_$i'.codeUnits),
      );
    }
    await store.enforceRetentionPolicy();
    final remaining = store.listSessions()..sort();
    // The 3 oldest should be gone; the last maxBundles should survive.
    final expected =
        sessionIds.sublist(3)..sort();
    expect(remaining, expected);
  });

  test('4. Repeated enforcement is idempotent when count == maxBundles', () async {
    for (var i = 0; i < ForensicStore.maxBundles; i++) {
      await store.writeBundle(
        sessionId: 'session_$i',
        payload: Uint8List.fromList('data_$i'.codeUnits),
      );
    }
    final first = await store.enforceRetentionPolicy();
    final second = await store.enforceRetentionPolicy();
    expect(first, 0);
    expect(second, 0);
  });
}
