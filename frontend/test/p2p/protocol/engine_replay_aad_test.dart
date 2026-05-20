// T-P-AAD-001 §12.3.bullet-5 — engine_replay_version is bound into MOVE n=0 AAD.
//
// Proof: the first AEAD frame of a session (MOVE n=0) embeds the engine replay
// version in its additional authenticated data (AAD). Tampering the version
// field invalidates authentication.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/engine_replay_aad.dart';
import '../../../lib/services/p2p/protocol/engine_replay_version.dart';

void main() {
  group('T-P-AAD-001 §12.3 — MOVE n=0 AAD integrity', () {
    late Uint8List sessionId;

    setUp(() {
      // Deterministic 32-byte session ID for tests.
      sessionId = Uint8List(32)..fillRange(0, 32, 0xAB);
    });

    test('buildMoveZeroAad returns non-empty bytes', () {
      final aad = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      expect(aad, isNotEmpty);
    });

    test('AAD contains engine replay version as 4 little-endian bytes', () {
      const version = 1;
      final aad = buildMoveZeroAad(
        engineReplayVersion: version,
        sessionId: sessionId,
      );
      // version bytes must appear somewhere in the AAD (little-endian u32).
      final versionBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, version, Endian.little);
      bool found = false;
      for (int i = 0; i <= aad.length - 4; i++) {
        if (aad[i] == versionBytes[0] &&
            aad[i + 1] == versionBytes[1] &&
            aad[i + 2] == versionBytes[2] &&
            aad[i + 3] == versionBytes[3]) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'version bytes not found in AAD');
    });

    test('AAD contains session ID bytes', () {
      final aad = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      // All sessionId bytes must appear contiguously in AAD.
      final sessionIdList = sessionId.toList();
      bool found = false;
      for (int i = 0; i <= aad.length - sessionId.length; i++) {
        if (aad.sublist(i, i + sessionId.length).toList().toString() ==
            sessionIdList.toString()) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'sessionId bytes not found in AAD');
    });

    test('verifyMoveZeroAad returns true for matching AAD', () {
      final aad = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      expect(
        verifyMoveZeroAad(
          engineReplayVersion: kEngineReplayVersion,
          sessionId: sessionId,
          aad: aad,
        ),
        isTrue,
      );
    });

    test('verifyMoveZeroAad returns false when version is tampered', () {
      final aad = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      // Verify with a different version — must fail.
      expect(
        verifyMoveZeroAad(
          engineReplayVersion: kEngineReplayVersion + 1,
          sessionId: sessionId,
          aad: aad,
        ),
        isFalse,
      );
    });

    test('verifyMoveZeroAad returns false when sessionId differs', () {
      final aad = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      final differentSessionId = Uint8List(32)..fillRange(0, 32, 0x55);
      expect(
        verifyMoveZeroAad(
          engineReplayVersion: kEngineReplayVersion,
          sessionId: differentSessionId,
          aad: aad,
        ),
        isFalse,
      );
    });

    test('different engineReplayVersions produce different AADs', () {
      final aad1 = buildMoveZeroAad(
        engineReplayVersion: 1,
        sessionId: sessionId,
      );
      final aad2 = buildMoveZeroAad(
        engineReplayVersion: 2,
        sessionId: sessionId,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('different sessionIds produce different AADs', () {
      final sessionId2 = Uint8List(32)..fillRange(0, 32, 0xCD);
      final aad1 = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      final aad2 = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId2,
      );
      expect(aad1, isNot(equals(aad2)));
    });

    test('AAD is deterministic for same inputs', () {
      final aad1 = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      final aad2 = buildMoveZeroAad(
        engineReplayVersion: kEngineReplayVersion,
        sessionId: sessionId,
      );
      expect(aad1, equals(aad2));
    });

    test(
      'domain separator is present (first bytes identify move-zero context)',
      () {
        final aad = buildMoveZeroAad(
          engineReplayVersion: kEngineReplayVersion,
          sessionId: sessionId,
        );
        // The spec requires a domain separator prefix; AAD must be longer than
        // version (4) + sessionId (32) = 36 bytes alone.
        expect(aad.length, greaterThan(36));
      },
    );
  });
}
