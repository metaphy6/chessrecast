import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('SessionKdf — X25519 + HKDF session key derivation (§2.3)', () {
    test('generateEphemeral produces 32-byte pub and priv keys', () {
      final kp = SessionKdf.generateEphemeral();
      expect(kp.publicKey.length, equals(32));
      expect(kp.privateKey.length, equals(32));
    });

    test('generateEphemeral produces unique keypairs', () {
      final kp1 = SessionKdf.generateEphemeral();
      final kp2 = SessionKdf.generateEphemeral();
      expect(kp1.publicKey, isNot(equals(kp2.publicKey)));
    });

    test('sharedSecret returns 32 bytes', () {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final secret = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      expect(secret.length, equals(32));
    });

    test('sessionMaster returns 32 bytes', () {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final ecdh = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      final sessionId = DeviceFingerprint.compute(alice.publicKey).codeUnits;
      final master = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: ecdh, // use ECDH as session ID salt for test
      );
      expect(master.length, equals(32));
    });

    test('same ECDH + sessionId yields identical master keys', () {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final ecdh = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      final sessionId = ecdh; // fixed session ID for determinism
      final m1 = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: sessionId,
      );
      final m2 = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: sessionId,
      );
      expect(m1, equals(m2));
    });

    test('different session IDs produce different master keys', () {
      final alice = SessionKdf.generateEphemeral();
      final bob = SessionKdf.generateEphemeral();
      final ecdh = SessionKdf.sharedSecret(
        myPrivateKey: alice.privateKey,
        theirPublicKey: bob.publicKey,
      );
      final m1 = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: alice.publicKey,
      );
      final m2 = SessionKdf.sessionMaster(
        ecdhSecret: ecdh,
        sessionId: bob.publicKey,
      );
      expect(m1, isNot(equals(m2)));
    });
  });
}
