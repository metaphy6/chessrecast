/// Proof test for roadmap §0.6.bullet-2 — Forensic-bundle at-rest encryption.
///
/// Verifies that [ForensicStore] stores bundles using authenticated encryption
/// (AES-256-GCM, the Phase-0 equivalent of libsodium crypto_secretstream):
///   1. Round-trip: written bundle decrypts correctly.
///   2. Bundle directory structure matches `p2p/forensics/<session-id>/`.
///   3. Raw bundle file contains no known plaintext.
///   4. Tampered ciphertext returns null (authentication fails gracefully).
///   5. Key persistence: bundles survive store close/reopen.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/forensic_store.dart';

void main() {
  test('1. round-trip: write and read returns correct bytes', () async {
    final dir = Directory.systemTemp.createTempSync('fstor_rt_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final store = ForensicStore(docsDir: dir.path);
    await store.init();

    final payload = Uint8List.fromList(
      'chess_forensic_data_session_abc'.codeUnits,
    );
    await store.writeBundle(sessionId: 'sess-001', payload: payload);
    final read = await store.readBundle(sessionId: 'sess-001');

    expect(read, isNotNull);
    expect(read, equals(payload));
  });

  test('2. bundle lives under p2p/forensics/<session-id>/', () async {
    final dir = Directory.systemTemp.createTempSync('fstor_dir_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final store = ForensicStore(docsDir: dir.path);
    await store.init();

    await store.writeBundle(
      sessionId: 'sess-path-test',
      payload: Uint8List.fromList([1, 2, 3]),
    );

    final expectedFile = File(
      '${dir.path}/p2p/forensics/sess-path-test/bundle.enc',
    );
    expect(expectedFile.existsSync(), isTrue,
        reason: 'Bundle must be at the expected path');
  });

  test('3. raw bundle file contains no known plaintext', () async {
    final dir = Directory.systemTemp.createTempSync('fstor_plain_');
    addTearDown(() => dir.deleteSync(recursive: true));

    const sentinel = 'PLAINTEXT_FORENSIC_DATA_SENTINEL';
    final store = ForensicStore(docsDir: dir.path);
    await store.init();

    await store.writeBundle(
      sessionId: 'sess-plain',
      payload: Uint8List.fromList(sentinel.codeUnits),
    );

    final raw = File('${dir.path}/p2p/forensics/sess-plain/bundle.enc')
        .readAsStringSync();
    expect(
      raw.contains(sentinel),
      isFalse,
      reason: 'Bundle file must not contain plaintext sentinel',
    );
  });

  test('4. tampered ciphertext returns null (authentication fails gracefully)',
      () async {
    final dir = Directory.systemTemp.createTempSync('fstor_tamper_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final store = ForensicStore(docsDir: dir.path);
    await store.init();

    await store.writeBundle(
      sessionId: 'sess-tamper',
      payload: Uint8List.fromList([10, 20, 30]),
    );

    // Corrupt the bundle file.
    File('${dir.path}/p2p/forensics/sess-tamper/bundle.enc')
        .writeAsStringSync('AAAA_tampered_BBBB');

    final result = await store.readBundle(sessionId: 'sess-tamper');
    expect(result, isNull,
        reason: 'Tampered bundle must return null, not garbage data');
  });

  test('5. bundles survive store close and reopen (key persistence)', () async {
    final dir = Directory.systemTemp.createTempSync('fstor_persist_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final payload = Uint8List.fromList('persistent_bundle_data'.codeUnits);

    final store1 = ForensicStore(docsDir: dir.path);
    await store1.init();
    await store1.writeBundle(sessionId: 'sess-persist', payload: payload);

    // Re-open with a new instance — must reload the KEK from disk.
    final store2 = ForensicStore(docsDir: dir.path);
    await store2.init();
    final read = await store2.readBundle(sessionId: 'sess-persist');

    expect(read, isNotNull);
    expect(read, equals(payload));
  });
}
