import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('WrappedBlob — KDF version upgrade re-wrap (§2.2)', () {
    late Uint8List accountKey;
    late RecoveryCode code;
    late Uint8List kek;
    late Uint8List aad;

    setUp(() {
      accountKey = Uint8List(32)..fillRange(0, 32, 0x42);
      code = RecoveryCode.generate();
      kek = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      aad = Uint8List(32)..fillRange(0, 32, 0x01);
    });

    test('wrap/unwrap round-trip with floor params', () {
      final blob = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: kek,
        aad: aad,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final recovered = blob.unwrap(kek: kek, aad: aad);
      expect(recovered, equals(accountKey));
    });

    test('encoded blob is ≤ 256 bytes', () {
      final blob = WrappedBlob.wrap(accountKey: accountKey, kek: kek, aad: aad);
      final encoded = blob.encode();
      expect(encoded.length, lessThanOrEqualTo(256));
    });

    test('encode/decode round-trip preserves all fields', () {
      final blob = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: kek,
        aad: aad,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final decoded = WrappedBlob.decode(blob.encode());
      expect(decoded.kdfVersion, equals(blob.kdfVersion));
      expect(decoded.mKib, equals(blob.mKib));
      expect(decoded.iterations, equals(blob.iterations));
      expect(decoded.salt, equals(blob.salt));
      expect(decoded.ciphertext, equals(blob.ciphertext));
    });

    test('re-wrap with higher params produces different ciphertext', () {
      final blob1 = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: kek,
        aad: aad,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      // Re-derive KEK with higher iterations for "upgrade"
      final kek2 = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin + 1,
      );
      final blob2 = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: kek2,
        aad: aad,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin + 1,
      );
      expect(blob2.ciphertext, isNot(equals(blob1.ciphertext)));
      // But both decrypt to the same account key
      expect(blob1.unwrap(kek: kek, aad: aad), equals(accountKey));
      expect(blob2.unwrap(kek: kek2, aad: aad), equals(accountKey));
    });

    test('unwrap with wrong KEK throws BlobIntegrityError', () {
      final blob = WrappedBlob.wrap(accountKey: accountKey, kek: kek, aad: aad);
      final wrongKek = Uint8List(32)..fillRange(0, 32, 0xFF);
      expect(
        () => blob.unwrap(kek: wrongKek, aad: aad),
        throwsA(isA<BlobIntegrityError>()),
      );
    });

    test('unwrap with wrong AAD throws BlobIntegrityError', () {
      final blob = WrappedBlob.wrap(accountKey: accountKey, kek: kek, aad: aad);
      final wrongAad = Uint8List(32)..fillRange(0, 32, 0xFF);
      expect(
        () => blob.unwrap(kek: kek, aad: wrongAad),
        throwsA(isA<BlobIntegrityError>()),
      );
    });
  });
}
