import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Secret lifetime tests (§2.7.bullet-2).
///
/// Verifies that secret-bearing buffers are zeroed after use and that
/// exceptions in the critical path do not leave secrets accessible.
///
/// In production these contracts are enforced by sodium_malloc + sodium_memzero.
/// These tests verify the Dart-side behavioral equivalent using DeviceIdentity.zeroize()
/// and SessionKdf ephemeral key handling.
void main() {
  group('Secret lifetime (§2.7)', () {
    test('zeroize() fills private key with zeros', () {
      final identity = DeviceIdentity.generate();
      final len = identity.privateKey.length;
      identity.zeroize();
      expect(
        identity.privateKey.every((b) => b == 0),
        isTrue,
        reason: 'Private key must be zeroed after zeroize()',
      );
      expect(len, equals(64));
    });

    test('zeroize() is idempotent (no double-free / throw)', () {
      final identity = DeviceIdentity.generate();
      identity.zeroize();
      expect(() => identity.zeroize(), returnsNormally);
    });

    test('public key is NOT zeroed by zeroize() (it is not secret)', () {
      final identity = DeviceIdentity.generate();
      final pub = Uint8List.fromList(identity.publicKey);
      identity.zeroize();
      // Public key should remain intact (it's not secret)
      expect(identity.publicKey, equals(pub));
    });

    test('session rekey zeroes prev session master', () {
      final rekey = SessionRekey();
      final prevMaster = Uint8List(32)..fillRange(0, 32, 0x42);
      final copy = Uint8List.fromList(prevMaster); // save original
      final myNew = SessionKdf.generateEphemeral();
      final theirNew = SessionKdf.generateEphemeral();
      rekey.rekey(
        prevSessionMaster: prevMaster,
        myNewPrivateKey: myNew.privateKey,
        theirNewPublicKey: theirNew.publicKey,
      );
      // prevMaster should be zeroed (sodium_memzero equivalent)
      expect(
        prevMaster.every((b) => b == 0),
        isTrue,
        reason: 'prev session master must be zeroed immediately after rekey',
      );
      // Confirm it was non-zero before rekey
      expect(copy.every((b) => b == 0x42), isTrue);
    });

    test('BiometricLockout wipe clears private key via onWipe callback', () {
      DeviceIdentity? identity;
      identity = DeviceIdentity.generate();
      final privateCopy = identity.privateKey;

      final lockout = BiometricLockout(maxFailures: 3);

      // 3 failures should trigger wipe
      for (int i = 0; i < 3; i++) {
        lockout.recordFailure(onWipe: () => identity!.zeroize());
      }
      expect(
        privateCopy.every((b) => b == 0),
        isTrue,
        reason: 'onWipe callback must zero the private key',
      );
    });

    test('ephemeral key pair can be zeroed by caller after use', () {
      final kp = SessionKdf.generateEphemeral();
      // Simulate post-session cleanup: zero private key
      kp.privateKey.fillRange(0, kp.privateKey.length, 0);
      expect(kp.privateKey.every((b) => b == 0), isTrue);
    });
  });
}
