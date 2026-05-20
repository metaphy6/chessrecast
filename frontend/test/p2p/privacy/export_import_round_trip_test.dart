/// Proof test for roadmap §18.4 — Right to Portability (export-my-data).
///
/// Round-trip test: export → decrypt → import reconstructs original data.
/// Also verifies that a bad passphrase causes import to fail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/privacy/export_service.dart';

void main() {
  group('§18.4 ExportService — export/import round trip', () {
    late ExportService service;

    setUp(() {
      service = ExportService.forTest();
    });

    test(
      'importArchive reconstructs payload with correct passphrase',
      () async {
        const passphrase = 'roundtrip-test-passphrase';
        final original = _testPayload();

        final archive = await service.exportArchive(
          payload: original,
          passphrase: passphrase,
        );

        final restored = await service.importArchive(
          archive: archive,
          passphrase: passphrase,
        );

        expect(restored.accountPubkey, equals(original.accountPubkey));
        expect(restored.devicePubkeys, equals(original.devicePubkeys));
        expect(
          restored.transcripts.length,
          equals(original.transcripts.length),
        );
        expect(
          restored.transcripts.first.moves,
          equals(original.transcripts.first.moves),
        );
        expect(
          restored.displayNameOverrides,
          equals(original.displayNameOverrides),
        );
        expect(restored.settings, equals(original.settings));
      },
    );

    test('importArchive throws on wrong passphrase', () async {
      final original = _testPayload();
      final archive = await service.exportArchive(
        payload: original,
        passphrase: 'correct-passphrase',
      );

      expect(
        () async => service.importArchive(
          archive: archive,
          passphrase: 'wrong-passphrase',
        ),
        throwsA(isA<ExportDecryptException>()),
      );
    });

    test('importArchive never restores wrappedRecoveryBlob', () async {
      // Even if something got corrupted, import must never return the blob.
      final original = _testPayload(wrappedRecoveryBlob: 'should-be-absent');
      final archive = await service.exportArchive(
        payload: original,
        passphrase: 'test-pass',
      );

      final restored = await service.importArchive(
        archive: archive,
        passphrase: 'test-pass',
      );

      expect(restored.wrappedRecoveryBlob, isNull);
    });

    test('exportFilename has expected pattern', () {
      final name = ExportService.exportFilename(
        accountShortId: 'aabb',
        date: DateTime(2025, 5, 20),
      );
      expect(name, equals('chessrecast-export-aabb-2025-05-20.cbor.aead'));
    });
  });
}

ExportPayload _testPayload({String? wrappedRecoveryBlob}) {
  return ExportPayload(
    accountPubkey: 'deadbeef01234567',
    devicePubkeys: ['dev-key-a', 'dev-key-b'],
    transcripts: [
      TranscriptEntry(id: 'g-1', moves: '1. d4 d5', signedBy: ['p1', 'p2']),
    ],
    blockList: ['blocked-pubkey'],
    displayNameOverrides: {'deadbeef': 'Bob'},
    settings: {'notifications': 'true'},
    wrappedRecoveryBlob: wrappedRecoveryBlob,
  );
}
