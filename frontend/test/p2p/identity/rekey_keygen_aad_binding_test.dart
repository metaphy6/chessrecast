import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Re-key keygen AAD binding tests (§2.10.bullet-2).
///
/// Verifies that the `keygen: u8` counter is bound into AEAD AAD so that
/// frames from the old key epoch cannot be replayed into the new key epoch.
void main() {
  group('Rekey keygen AAD binding (§2.10)', () {
    late Uint8List sessionId;

    setUp(() {
      sessionId = Uint8List(16)..fillRange(0, 16, 0xAB);
    });

    test('buildAad includes keygen counter', () {
      final aad0 = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 2,
        sessionId: sessionId,
        keygenCounter: 0,
      );
      final aad1 = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 2,
        sessionId: sessionId,
        keygenCounter: 1,
      );
      // AAD bytes must differ across key epochs
      expect(aad0, isNot(equals(aad1)));
    });

    test('buildAad is deterministic for same inputs', () {
      final aad1 = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 3,
        sessionId: sessionId,
        keygenCounter: 5,
      );
      final aad2 = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 3,
        sessionId: sessionId,
        keygenCounter: 5,
      );
      expect(aad1, equals(aad2));
    });

    test('cross-epoch replay is rejected by AEAD (wrong AAD)', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x42);
      final salt = AeadCipher.deriveSalt15(
        sharedSecret: key,
        sessionId: sessionId,
      );

      // Epoch 0: Alice encrypts with keygen=0 AAD
      final aad0 = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 1,
        sessionId: sessionId,
        keygenCounter: 0,
      );
      final aad1 = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 1,
        sessionId: sessionId,
        keygenCounter: 1,
      );

      final enc0 = AeadCipher(key: key, salt15: salt, direction: 0);
      final pt = Uint8List.fromList([1, 2, 3, 4]);
      final ct0 = enc0.encrypt(pt, aad: aad0); // encrypted with epoch-0 AAD

      // Epoch 1 decrypt must fail: AAD1 doesn't match what was used for ct0
      final dec1 = AeadCipher(key: key, salt15: salt, direction: 0);
      expect(
        () => dec1.decrypt(ct0, aad: aad1, seq: 0),
        throwsA(isA<AeadDecryptError>()),
        reason:
            'Cross-epoch replay must be rejected due to keygen AAD mismatch',
      );
    });

    test('within same epoch, frames decrypt correctly', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x77);
      final salt = AeadCipher.deriveSalt15(
        sharedSecret: key,
        sessionId: sessionId,
      );
      final aad = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 1,
        sessionId: sessionId,
        keygenCounter: 2,
      );

      final enc = AeadCipher(key: key, salt15: salt, direction: 0);
      final dec = AeadCipher(key: key, salt15: salt, direction: 0);
      final pt = Uint8List.fromList('chess'.codeUnits);
      final ct = enc.encrypt(pt, aad: aad);
      final recovered = dec.decrypt(ct, aad: aad, seq: 0);
      expect(recovered, equals(pt));
    });

    test('AAD length = 3 + session_id.length', () {
      final aad = RekeyAadBinding.buildAad(
        wireVersion: 1,
        frameType: 1,
        sessionId: sessionId,
        keygenCounter: 0,
      );
      expect(aad.length, equals(3 + sessionId.length));
    });
  });
}
