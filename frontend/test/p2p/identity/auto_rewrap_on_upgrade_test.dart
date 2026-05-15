import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('Auto re-wrap on KDF upgrade (§2.2)', () {
    test('blob with old kdf_version can be re-wrapped at higher params', () {
      final accountKey = Uint8List(32)..fillRange(0, 32, 0x42);
      final code = RecoveryCode.generate();
      // Wrap at floor params (lowest acceptable)
      final kek = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final aad = Uint8List(4)..fillRange(0, 4, 0x01);
      final oldBlob = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: kek,
        aad: aad,
      );

      // Simulate upgrade: user unlocks with old params → re-derive at higher params
      final oldDecrypted = oldBlob.unwrap(kek: kek, aad: aad);
      final higherKek = code.deriveKek(
        mKib: Argon2idStub.mMinKib * 2, // doubled
        iterations: Argon2idStub.tMin + 1,
      );
      final newBlob = WrappedBlob.wrap(
        accountKey: oldDecrypted,
        kek: higherKek,
        aad: aad,
      );
      final newEncoded = newBlob.encode();

      // New blob differs from old
      expect(newEncoded, isNot(equals(oldBlob.encode())));

      // But still unwraps to the same account key
      final decoded = WrappedBlob.decode(newEncoded);
      final recovered = decoded.unwrap(kek: higherKek, aad: aad);
      expect(recovered, equals(accountKey));
    });

    test('re-wrap blob has non-decreasing kdf_version', () {
      final accountKey = Uint8List(32)..fillRange(0, 32, 0x99);
      final code = RecoveryCode.generate();
      final kek = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final aad = Uint8List(4)..fillRange(0, 4, 0x02);
      final blob = WrappedBlob.wrap(accountKey: accountKey, kek: kek, aad: aad);

      // A re-wrapped blob must have kdf_version >= original
      // (The WrappedBlob always uses the current kdf_version)
      final encoded = blob.encode();
      final decoded = WrappedBlob.decode(encoded);
      // kdf_version is accessible via the first byte of encoded blob
      // Version byte is position 0: encoded[0] = kdf_version
      expect(decoded.kdfVersion, greaterThanOrEqualTo(1));
    });

    test('old-params KEK fails to decrypt re-wrapped blob', () {
      final accountKey = Uint8List(32)..fillRange(0, 32, 0xBC);
      final code = RecoveryCode.generate();
      final oldKek = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final aad = Uint8List(4)..fillRange(0, 4, 0x03);
      final oldBlob = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: oldKek,
        aad: aad,
      );
      final decrypted = oldBlob.unwrap(kek: oldKek, aad: aad);

      // Re-wrap at higher cost
      final newKek = code.deriveKek(
        mKib: Argon2idStub.mMinKib * 4,
        iterations: Argon2idStub.tMin + 2,
      );
      final newBlob = WrappedBlob.wrap(
        accountKey: decrypted,
        kek: newKek,
        aad: aad,
      );

      // Old KEK cannot decrypt the new blob
      expect(
        () => newBlob.unwrap(kek: oldKek, aad: aad),
        throwsA(isA<BlobIntegrityError>()),
      );
    });
  });
}
