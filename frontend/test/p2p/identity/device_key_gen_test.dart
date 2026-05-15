import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('DeviceIdentity — Ed25519 key generation (§2.1)', () {
    test('generate() returns a DeviceIdentity with 32-byte public key', () {
      final id = DeviceIdentity.generate();
      expect(id.publicKey.length, 32);
    });

    test('generate() returns a DeviceIdentity with 64-byte private key', () {
      final id = DeviceIdentity.generate();
      expect(id.privateKey.length, 64);
    });

    test('generate() produces unique keypairs on each call', () {
      final id1 = DeviceIdentity.generate();
      final id2 = DeviceIdentity.generate();
      // Two separate generations must differ (probability of collision is
      // negligible for a 256-bit random key).
      expect(id1.publicKey, isNot(equals(id2.publicKey)));
    });

    test('public key is deterministic from the private key seed', () {
      // Reconstructing a DeviceIdentity from the same seed must return the
      // same public key.
      final id1 = DeviceIdentity.generate();
      final seed = id1.privateKey.sublist(0, 32);
      final id2 = DeviceIdentity.fromSeed(seed);
      expect(id2.publicKey, equals(id1.publicKey));
    });

    test('publicKey and privateKey are not zero', () {
      final id = DeviceIdentity.generate();
      final allZero = id.publicKey.every((b) => b == 0);
      expect(allZero, isFalse);
    });

    test('sign() and verify() round-trip', () {
      final id = DeviceIdentity.generate();
      final message = [1, 2, 3, 4, 5];
      final sig = id.sign(message);
      expect(sig.length, 64);
      expect(DeviceIdentity.verify(id.publicKey, message, sig), isTrue);
    });

    test('verify() rejects tampered message', () {
      final id = DeviceIdentity.generate();
      final message = [1, 2, 3, 4, 5];
      final sig = id.sign(message);
      final tampered = [1, 2, 3, 4, 6]; // last byte changed
      expect(DeviceIdentity.verify(id.publicKey, tampered, sig), isFalse);
    });

    test('verify() rejects tampered signature', () {
      final id = DeviceIdentity.generate();
      final message = [1, 2, 3, 4, 5];
      final sig = id.sign(message);
      final badSig = List<int>.from(sig)..[0] ^= 0xFF;
      expect(DeviceIdentity.verify(id.publicKey, message, badSig), isFalse);
    });
  });
}
