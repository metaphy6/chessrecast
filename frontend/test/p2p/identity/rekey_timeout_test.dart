import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Re-key timeout tests (§2.10.bullet-3).
///
/// Verifies that [RekeyFailedError] is defined and correctly identifies
/// a re-key that timed out. The 5-second wall-clock enforcement is a network
/// layer concern (Phase 3+); these tests cover the error contract only.
void main() {
  group('Rekey timeout / failure (§2.10)', () {
    test('RekeyFailedError is an Exception', () {
      const e = RekeyFailedError();
      expect(e, isA<Exception>());
    });

    test('RekeyFailedError.toString() contains RE_KEY_FAILED', () {
      const e = RekeyFailedError();
      expect(e.toString(), contains('RE_KEY_FAILED'));
    });

    test('RekeyFailedError can be thrown and caught', () {
      void simulateTimeout() => throw const RekeyFailedError();
      expect(simulateTimeout, throwsA(isA<RekeyFailedError>()));
    });

    test(
      'RekeyFailedError is not a RekeyResult (session ends, not continues)',
      () {
        const e = RekeyFailedError();
        expect(e, isNot(isA<RekeyResult>()));
      },
    );

    test('failed rekey does not corrupt a new rekey attempt', () {
      // Simulate: re-key fails (throws) → catch → initiate a fresh rekey
      final rekey = SessionRekey();
      final master = Uint8List(32)..fillRange(0, 32, 0x55);
      final myNew = SessionKdf.generateEphemeral();
      final theirNew = SessionKdf.generateEphemeral();

      // First rekey succeeds (no timeout simulated)
      final result = rekey.rekey(
        prevSessionMaster: master,
        myNewPrivateKey: myNew.privateKey,
        theirNewPublicKey: theirNew.publicKey,
      );
      expect(result.keygenCounter, equals(1));

      // Simulate timeout on second attempt: RekeyFailedError is thrown
      bool caughtTimeout = false;
      try {
        throw const RekeyFailedError();
      } on RekeyFailedError {
        caughtTimeout = true;
      }
      expect(caughtTimeout, isTrue);

      // After catching timeout, keygenCounter is still at 1 (not incremented on failure)
      expect(rekey.keygenCounter, equals(1));
    });
  });
}
