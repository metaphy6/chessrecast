import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('AEAD — AAD binding prevents cross-context replay (§2.3)', () {
    test('encrypt with AAD_A, decrypt with AAD_B fails', () {
      final key = Uint8List(32)..fillRange(0, 32, 0xCC);
      final salt = Uint8List(15)..fillRange(0, 15, 0x11);
      final enc = AeadCipher(key: key, salt15: salt, direction: 0);
      final dec = AeadCipher(key: key, salt15: salt, direction: 0);
      final pt = Uint8List.fromList([1, 2, 3, 4, 5]);
      final aadA = Uint8List.fromList('session-abc'.codeUnits);
      final aadB = Uint8List.fromList('session-xyz'.codeUnits);

      final ct = enc.encrypt(pt, aad: aadA);
      expect(
        () => dec.decrypt(ct, aad: aadB, seq: 0),
        throwsA(isA<AeadDecryptError>()),
      );
    });

    test('empty AAD and non-empty AAD produce different ciphertexts', () {
      final key = Uint8List(32)..fillRange(0, 32, 0xDD);
      final salt = Uint8List(15)..fillRange(0, 15, 0x22);
      final enc1 = AeadCipher(key: key, salt15: salt, direction: 0);
      final enc2 = AeadCipher(key: key, salt15: salt, direction: 0);
      final pt = Uint8List.fromList([10, 20, 30]);
      final ct1 = enc1.encrypt(pt, aad: Uint8List(0));
      final ct2 = enc2.encrypt(pt, aad: Uint8List.fromList([0xFF]));
      // The plaintexts are the same, but different AADs change the tag
      // (different tag means different ciphertext output)
      expect(ct1, isNot(equals(ct2)));
    });

    test(
      'same plaintext + same key + same AAD + different seq yields different ciphertext',
      () {
        final key = Uint8List(32)..fillRange(0, 32, 0xEE);
        final salt = Uint8List(15)..fillRange(0, 15, 0x33);
        final enc = AeadCipher(key: key, salt15: salt, direction: 0);
        final pt = Uint8List.fromList([0x42, 0x42]);
        final aad = Uint8List.fromList('aad'.codeUnits);
        final ct0 = enc.encrypt(pt, aad: aad); // seq=0
        final ct1 = enc.encrypt(pt, aad: aad); // seq=1
        expect(ct0, isNot(equals(ct1)));
      },
    );
  });

  group('AEAD AAD session-ID binding (§2.3)', () {
    test('decryption with correct session_id AAD succeeds', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x11);
      final salt = Uint8List(15)..fillRange(0, 15, 0x22);
      final sessionId = Uint8List.fromList('session-xyz'.codeUnits);
      final enc = AeadCipher(key: key, salt15: salt, direction: 0);
      final dec = AeadCipher(key: key, salt15: salt, direction: 0);
      final pt = Uint8List.fromList('move e2e4'.codeUnits);
      final ct = enc.encrypt(pt, aad: sessionId);
      final recovered = dec.decrypt(ct, aad: sessionId, seq: 0);
      expect(recovered, equals(pt));
    });

    test('decryption with wrong session_id AAD throws AeadDecryptError', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x33);
      final salt = Uint8List(15)..fillRange(0, 15, 0x44);
      final sessionId = Uint8List.fromList('session-abc'.codeUnits);
      final wrongId = Uint8List.fromList('session-xyz'.codeUnits);
      final enc = AeadCipher(key: key, salt15: salt, direction: 0);
      final dec = AeadCipher(key: key, salt15: salt, direction: 0);
      final pt = Uint8List(8);
      final ct = enc.encrypt(pt, aad: sessionId);
      expect(
        () => dec.decrypt(ct, aad: wrongId, seq: 0),
        throwsA(isA<AeadDecryptError>()),
      );
    });

    test('empty AAD works (fallback path)', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x55);
      final salt = Uint8List(15)..fillRange(0, 15, 0x66);
      final enc = AeadCipher(key: key, salt15: salt, direction: 0);
      final dec = AeadCipher(key: key, salt15: salt, direction: 0);
      final pt = Uint8List.fromList([42, 43, 44]);
      final ct = enc.encrypt(pt, aad: Uint8List(0));
      final recovered = dec.decrypt(ct, aad: Uint8List(0), seq: 0);
      expect(recovered, equals(pt));
    });
  });
}
