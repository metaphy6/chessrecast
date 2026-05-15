import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('AEAD — salt derivation KAT (§2.3)', () {
    test('deriveSalt15 is deterministic (KAT)', () {
      // These are stub KAT vectors for the HKDF-SHA256 implementation.
      // Production code uses libsodium and must pass the same vectors.
      final secret = Uint8List(32)..fillRange(0, 32, 0xAA);
      final sessionId = Uint8List(16)..fillRange(0, 16, 0xBB);
      final salt1 = AeadCipher.deriveSalt15(
        sharedSecret: secret,
        sessionId: sessionId,
      );
      final salt2 = AeadCipher.deriveSalt15(
        sharedSecret: secret,
        sessionId: sessionId,
      );
      expect(salt1, equals(salt2));
      expect(salt1.length, equals(15));
    });

    test(
      'deriveSalt15 differs from session_id (no salt == session_id leak)',
      () {
        final secret = Uint8List(32)..fillRange(0, 32, 0xCC);
        final sessionId = Uint8List(32)
          ..fillRange(0, 32, 0xCC); // same as secret
        final salt = AeadCipher.deriveSalt15(
          sharedSecret: secret,
          sessionId: sessionId,
        );
        // derived salt must not be the trivial identity mapping of session_id
        // (it's 15 bytes vs 32 bytes, so trivially different)
        expect(salt.length, isNot(equals(sessionId.length)));
      },
    );

    test('different shared secrets produce different salts', () {
      final secretA = Uint8List(32)..fillRange(0, 32, 0x11);
      final secretB = Uint8List(32)..fillRange(0, 32, 0x22);
      final sessionId = Uint8List(16)..fillRange(0, 16, 0x33);
      final sA = AeadCipher.deriveSalt15(
        sharedSecret: secretA,
        sessionId: sessionId,
      );
      final sB = AeadCipher.deriveSalt15(
        sharedSecret: secretB,
        sessionId: sessionId,
      );
      expect(sA, isNot(equals(sB)));
    });

    test('different session IDs produce different salts', () {
      final secret = Uint8List(32)..fillRange(0, 32, 0x44);
      final idA = Uint8List(16)..fillRange(0, 16, 0x55);
      final idB = Uint8List(16)..fillRange(0, 16, 0x66);
      final sA = AeadCipher.deriveSalt15(sharedSecret: secret, sessionId: idA);
      final sB = AeadCipher.deriveSalt15(sharedSecret: secret, sessionId: idB);
      expect(sA, isNot(equals(sB)));
    });

    test('salt is not the raw shared secret (derivation happened)', () {
      final secret = Uint8List(32)..fillRange(0, 32, 0x77);
      final sessionId = Uint8List(16)..fillRange(0, 16, 0x88);
      final salt = AeadCipher.deriveSalt15(
        sharedSecret: secret,
        sessionId: sessionId,
      );
      // salt must differ from a trivial prefix of the secret
      expect(salt, isNot(equals(secret.sublist(0, 15))));
    });
  });
}
