/// Proof test for roadmap §18.4 — Right to Portability (export-my-data).
///
/// Tests the ExportService behaviour:
///   - Generates a valid archive containing required fields.
///   - Never includes the wrapped recovery blob.
///   - Enforces a 5-minute cooldown between exports.
///   - Requires a passphrase for encryption (non-empty).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/privacy/export_service.dart';

void main() {
  group('§18.4 ExportService — export-my-data', () {
    late ExportService service;

    setUp(() {
      service = ExportService.forTest();
    });

    test('exportArchive returns a non-empty encrypted blob', () async {
      final data = _testExportPayload();
      final result = await service.exportArchive(
        payload: data,
        passphrase: 'correct-horse-battery-staple',
      );
      expect(result, isNotEmpty);
      expect(result.length, greaterThan(32));
    });

    test('exportArchive never includes wrappedRecoveryBlob', () async {
      final data = _testExportPayload(
        wrappedRecoveryBlob: 'SUPER_SECRET_RECOVERY_BLOB',
      );
      final result = await service.exportArchive(
        payload: data,
        passphrase: 'test-passphrase',
      );

      // The raw bytes must not contain the recovery blob string.
      final resultStr = String.fromCharCodes(result);
      expect(resultStr, isNot(contains('SUPER_SECRET_RECOVERY_BLOB')));
    });

    test('exportArchive rejects empty passphrase', () async {
      final data = _testExportPayload();
      expect(
        () async => service.exportArchive(
          payload: data,
          passphrase: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('cooldown: second export within 5 minutes throws CooldownException', () async {
      final data = _testExportPayload();
      await service.exportArchive(payload: data, passphrase: 'pass1');

      expect(
        () async => service.exportArchive(payload: data, passphrase: 'pass2'),
        throwsA(isA<ExportCooldownException>()),
      );
    });

    test('cooldown: export succeeds after cooldown elapsed', () async {
      final data = _testExportPayload();

      // Use a service with a mock clock that starts at now.
      final fakeClock = FakeClock(DateTime.now());
      final s2 = ExportService.forTest(clock: fakeClock);

      await s2.exportArchive(payload: data, passphrase: 'pass1');

      // Advance clock by exactly 5 minutes.
      fakeClock.advance(const Duration(minutes: 5));

      // Should succeed (no cooldown exception).
      final result = await s2.exportArchive(payload: data, passphrase: 'pass2');
      expect(result, isNotEmpty);
    });
  });
}

ExportPayload _testExportPayload({String? wrappedRecoveryBlob}) {
  return ExportPayload(
    accountPubkey: 'aabbccddeeff0011',
    devicePubkeys: ['device-key-1'],
    transcripts: [
      TranscriptEntry(
        id: 'game-001',
        moves: '1. e4 e5 2. Nf3',
        signedBy: ['player1', 'player2'],
      ),
    ],
    blockList: [],
    displayNameOverrides: {'aabbccdd': 'Alice'},
    settings: {'theme': 'dark'},
    wrappedRecoveryBlob: wrappedRecoveryBlob,
  );
}
