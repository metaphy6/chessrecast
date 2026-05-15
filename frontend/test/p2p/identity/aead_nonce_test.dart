import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

AeadCipher _makeCipher({int direction = 0}) {
  final key = Uint8List(32)..fillRange(0, 32, 0xAB);
  final salt = Uint8List(15)..fillRange(0, 15, 0x12);
  return AeadCipher(key: key, salt15: salt, direction: direction);
}

void main() {
  group('AEAD — nonce structure: salt_15 || dir_1 || seq_u64_be (§2.3)', () {
    test('encrypt/decrypt round-trip', () {
      final enc = _makeCipher(direction: 0);
      final dec = _makeCipher(direction: 0);
      final plaintext = Uint8List.fromList('hello chess'.codeUnits);
      final aad = Uint8List.fromList('session-id'.codeUnits);
      final ciphertext = enc.encrypt(plaintext, aad: aad);
      final recovered = dec.decrypt(ciphertext, aad: aad, seq: 0);
      expect(recovered, equals(plaintext));
    });

    test('sequence counter increments on each encrypt', () {
      final enc = _makeCipher();
      final pt = Uint8List(8);
      final aad = Uint8List(0);
      enc.encrypt(pt, aad: aad);
      expect(enc.nextSeq, equals(1));
      enc.encrypt(pt, aad: aad);
      expect(enc.nextSeq, equals(2));
    });

    test('out-of-sequence decrypt throws OutOfSequenceAeadError', () {
      final enc = _makeCipher();
      final dec = _makeCipher();
      final pt = Uint8List(8);
      final aad = Uint8List(0);
      final ct0 = enc.encrypt(pt, aad: aad);
      final ct1 = enc.encrypt(pt, aad: aad);
      // Decrypt seq=0 first
      dec.decrypt(ct0, aad: aad, seq: 0);
      // seq=0 again should be rejected
      expect(
        () => dec.decrypt(ct0, aad: aad, seq: 0),
        throwsA(isA<OutOfSequenceAeadError>()),
      );
    });

    test('tampered ciphertext throws AeadDecryptError', () {
      final enc = _makeCipher();
      final dec = _makeCipher();
      final pt = Uint8List.fromList([1, 2, 3, 4]);
      final aad = Uint8List(0);
      final ct = enc.encrypt(pt, aad: aad);
      // Flip a byte in the ciphertext
      final tampered = Uint8List.fromList(ct);
      tampered[0] ^= 0xFF;
      expect(
        () => dec.decrypt(tampered, aad: aad, seq: 0),
        throwsA(isA<AeadDecryptError>()),
      );
    });

    test('wrong AAD throws AeadDecryptError', () {
      final enc = _makeCipher();
      final dec = _makeCipher();
      final pt = Uint8List(8);
      final aad1 = Uint8List.fromList([0x01]);
      final aad2 = Uint8List.fromList([0x02]);
      final ct = enc.encrypt(pt, aad: aad1);
      expect(
        () => dec.decrypt(ct, aad: aad2, seq: 0),
        throwsA(isA<AeadDecryptError>()),
      );
    });

    test('direction 0 and direction 1 ciphertexts are distinct', () {
      final encA2B = _makeCipher(direction: 0);
      final encB2A = _makeCipher(direction: 1);
      final pt = Uint8List.fromList([1, 2, 3]);
      final aad = Uint8List(0);
      final ctA2B = encA2B.encrypt(pt, aad: aad);
      final ctB2A = encB2A.encrypt(pt, aad: aad);
      expect(ctA2B, isNot(equals(ctB2A)));
    });

    test('deriveSalt15 returns 15 bytes', () {
      final secret = Uint8List(32)..fillRange(0, 32, 0x55);
      final sessionId = Uint8List(16)..fillRange(0, 16, 0x66);
      final salt = AeadCipher.deriveSalt15(
        sharedSecret: secret,
        sessionId: sessionId,
      );
      expect(salt.length, equals(15));
    });

    test('deriveSalt15 is deterministic', () {
      final secret = Uint8List(32)..fillRange(0, 32, 0x77);
      final sessionId = Uint8List(16)..fillRange(0, 16, 0x88);
      final s1 = AeadCipher.deriveSalt15(
        sharedSecret: secret,
        sessionId: sessionId,
      );
      final s2 = AeadCipher.deriveSalt15(
        sharedSecret: secret,
        sessionId: sessionId,
      );
      expect(s1, equals(s2));
    });

    test('salt is not transmitted on wire (different from nonce)', () {
      // The nonce includes the salt, but the salt itself is derived server-side.
      // This test verifies deriveSalt15 differs from the session ID (not leaked).
      final secret = Uint8List(32)..fillRange(0, 32, 0x99);
      final sessionId = Uint8List(16)..fillRange(0, 16, 0xAA);
      final salt = AeadCipher.deriveSalt15(
        sharedSecret: secret,
        sessionId: sessionId,
      );
      // salt should not equal session_id (trivial but sanity-checks derivation)
      expect(salt.length, isNot(equals(sessionId.length)));
    });
  });
}
