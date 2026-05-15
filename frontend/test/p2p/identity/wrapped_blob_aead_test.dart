import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('WrappedBlob — AEAD integrity (§2.4)', () {
    Uint8List _freshKek() {
      final code = RecoveryCode.generate();
      return code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
    }

    test('correct wrap/unwrap succeeds', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x42);
      final kek = _freshKek();
      final aad = Uint8List(32)..fillRange(0, 32, 0x01);
      final blob = WrappedBlob.wrap(accountKey: key, kek: kek, aad: aad);
      expect(blob.unwrap(kek: kek, aad: aad), equals(key));
    });

    test('single bit flip in ciphertext triggers BlobIntegrityError', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x42);
      final kek = _freshKek();
      final aad = Uint8List(32)..fillRange(0, 32, 0x01);
      final encoded = WrappedBlob.wrap(
        accountKey: key,
        kek: kek,
        aad: aad,
      ).encode();
      // Flip a bit in the ciphertext portion (bytes 23..54)
      encoded[25] ^= 0x01;
      final decoded = WrappedBlob.decode(encoded);
      expect(
        () => decoded.unwrap(kek: kek, aad: aad),
        throwsA(isA<BlobIntegrityError>()),
      );
    });

    test('wrong KEK triggers BlobIntegrityError', () {
      final key = Uint8List(32)..fillRange(0, 32, 0x55);
      final kek = _freshKek();
      final wrongKek = Uint8List(32)..fillRange(0, 32, 0xFF);
      final aad = Uint8List(32)..fillRange(0, 32, 0x02);
      final blob = WrappedBlob.wrap(accountKey: key, kek: kek, aad: aad);
      expect(
        () => blob.unwrap(kek: wrongKek, aad: aad),
        throwsA(isA<BlobIntegrityError>()),
      );
    });

    test('blob is exactly 87 bytes encoded', () {
      final key = Uint8List(32);
      final kek = _freshKek();
      final aad = Uint8List(32);
      final encoded = WrappedBlob.wrap(
        accountKey: key,
        kek: kek,
        aad: aad,
      ).encode();
      expect(encoded.length, equals(87));
    });
  });
}
