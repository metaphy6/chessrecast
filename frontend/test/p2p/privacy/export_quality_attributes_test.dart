/// Quality-attribute tests for ExportService — roadmap §18.7.
///
/// Covers Performance, Efficiency, Stability, Reliability, and Integrity.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chessrecast/services/p2p/privacy/export_service.dart';

ExportPayload _makePayload({int transcriptCount = 5}) => ExportPayload(
  accountPubkey: 'aabbcc' * 10,
  devicePubkeys: ['ddeeff' * 10],
  transcripts: List.generate(
    transcriptCount,
    (i) => TranscriptEntry(
      id: 'game-$i',
      moves: 'e2e4 e7e5 g1f3 b8c6 f1c4 g8f6',
      signedBy: ['aabbcc' * 10],
    ),
  ),
  blockList: [],
  displayNameOverrides: {},
  settings: {'theme': 'dark'},
);

void main() {
  group('§18.7.1 Performance — export ≤ 100 transcripts in < 30 s', () {
    test('100-transcript export completes within 30 seconds', () async {
      final svc = ExportService.forTest();
      final payload = _makePayload(transcriptCount: 100);
      final sw = Stopwatch()..start();
      final archive = await svc.exportArchive(
        payload: payload,
        passphrase: 'bench-passphrase',
      );
      sw.stop();
      expect(archive, isNotEmpty, reason: 'archive must be non-empty');
      expect(
        sw.elapsed.inSeconds,
        lessThan(30),
        reason: '100-transcript export must complete in < 30 s',
      );
    });
  });

  group('§18.7.2 Efficiency — archive ≤ 10 MB for typical account', () {
    test('archive for 100 transcripts is ≤ 10 MB', () async {
      final svc = ExportService.forTest();
      final payload = _makePayload(transcriptCount: 100);
      final archive = await svc.exportArchive(
        payload: payload,
        passphrase: 'efficiency-passphrase',
      );
      const tenMiB = 10 * 1024 * 1024;
      expect(
        archive.length,
        lessThanOrEqualTo(tenMiB),
        reason: 'archive for a typical account must be ≤ 10 MB',
      );
    });

    test('archive for 1 transcript is ≤ 100 kB (sanity check)', () async {
      final svc = ExportService.forTest();
      final payload = _makePayload(transcriptCount: 1);
      final archive = await svc.exportArchive(
        payload: payload,
        passphrase: 'small-passphrase',
      );
      const oneHundredKiB = 100 * 1024;
      expect(archive.length, lessThanOrEqualTo(oneHundredKiB));
    });
  });

  group('§18.7.3 Stability — export is async (isolate-friendly)', () {
    test('exportArchive returns a Future (UI never blocks)', () {
      final svc = ExportService.forTest();
      final payload = _makePayload();
      // Calling exportArchive must return a Future immediately — the work is
      // asynchronous. The UI layer is responsible for dispatching via compute()
      // or a p2p isolate; this test verifies the contract is Future-based.
      final future = svc.exportArchive(
        payload: payload,
        passphrase: 'async-passphrase',
      );
      expect(
        future,
        isA<Future<Uint8List>>(),
        reason:
            'exportArchive must return a Future so the UI can run it off the main thread',
      );
    });

    test('importArchive returns a Future (isolate-friendly)', () async {
      final svc = ExportService.forTest();
      final payload = _makePayload();
      final archive = await svc.exportArchive(
        payload: payload,
        passphrase: 'stability-passphrase',
      );
      final future = svc.importArchive(
        archive: archive,
        passphrase: 'stability-passphrase',
      );
      expect(future, isA<Future<ExportPayload>>());
    });
  });

  group('§18.7.4 Reliability — retry after failed export', () {
    test('hasPendingRetry is false initially', () {
      final svc = ExportService.forTest();
      expect(svc.hasPendingRetry, isFalse);
    });

    test('hasPendingRetry is false after successful export', () async {
      final svc = ExportService.forTest();
      final payload = _makePayload();
      await svc.exportArchive(payload: payload, passphrase: 'ok-pass');
      expect(
        svc.hasPendingRetry,
        isFalse,
        reason: 'successful export clears pending retry state',
      );
    });

    test(
      'seedRetryForTest + retryExport re-exports the seeded payload',
      () async {
        final svc = ExportService.forTest();
        final payload = _makePayload();
        // Simulate a mid-export crash by seeding retry state directly.
        svc.seedRetryForTest(payload);
        expect(
          svc.hasPendingRetry,
          isTrue,
          reason: 'seedRetryForTest must set hasPendingRetry',
        );
        final archive = await svc.retryExport(passphrase: 'retry-passphrase');
        expect(
          archive,
          isNotEmpty,
          reason: 'retryExport must produce a valid archive',
        );
        expect(
          svc.hasPendingRetry,
          isFalse,
          reason: 'successful retryExport clears pending retry state',
        );
      },
    );

    test('retryExport throws StateError when no pending retry', () {
      final svc = ExportService.forTest();
      expect(
        () => svc.retryExport(passphrase: 'noop'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group(
    '§18.7.5 Integrity — manifest signed under device key, tamper detection',
    () {
      test('archive with manifest round-trips and verifies', () async {
        final svc = ExportService.forTest();
        final payload = _makePayload();
        final deviceKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
        final archive = await svc.exportArchive(
          payload: payload,
          passphrase: 'integrity-pass',
          deviceKeyBytes: deviceKey,
        );
        final restored = await svc.importArchive(
          archive: archive,
          passphrase: 'integrity-pass',
          deviceKeyBytes: deviceKey,
        );
        expect(restored.accountPubkey, equals(payload.accountPubkey));
      });

      test('tampered archive byte throws ExportDecryptException', () async {
        final svc = ExportService.forTest();
        final payload = _makePayload();
        final archive = await svc.exportArchive(
          payload: payload,
          passphrase: 'tamper-pass',
        );
        // Flip a bit in the ciphertext region (after salt+nonce).
        final tampered = Uint8List.fromList(archive);
        tampered[28 + 10] ^= 0xFF; // somewhere in the ciphertext
        expect(
          () => svc.importArchive(archive: tampered, passphrase: 'tamper-pass'),
          throwsA(isA<ExportDecryptException>()),
          reason: 'AES-GCM tag verification must reject tampered ciphertext',
        );
      });

      test(
        'wrong device key on import throws ExportDecryptException',
        () async {
          final svc = ExportService.forTest();
          final payload = _makePayload();
          final deviceKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
          final wrongKey = Uint8List.fromList(List.generate(32, (i) => i + 2));
          final archive = await svc.exportArchive(
            payload: payload,
            passphrase: 'key-mismatch-pass',
            deviceKeyBytes: deviceKey,
          );
          expect(
            () => svc.importArchive(
              archive: archive,
              passphrase: 'key-mismatch-pass',
              deviceKeyBytes: wrongKey,
            ),
            throwsA(isA<ExportDecryptException>()),
            reason: 'wrong device key must fail manifest verification',
          );
        },
      );

      test('manifest includes transcript count and account pubkey', () async {
        final svc = ExportService.forTest();
        final payload = _makePayload(transcriptCount: 7);
        final deviceKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
        final archive = await svc.exportArchive(
          payload: payload,
          passphrase: 'manifest-check-pass',
          deviceKeyBytes: deviceKey,
        );
        final restored = await svc.importArchive(
          archive: archive,
          passphrase: 'manifest-check-pass',
          deviceKeyBytes: deviceKey,
        );
        expect(restored.transcripts.length, equals(7));
        expect(restored.accountPubkey, equals(payload.accountPubkey));
      });
    },
  );
}
