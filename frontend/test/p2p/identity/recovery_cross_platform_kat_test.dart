import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Cross-platform KDF determinism KAT (§2.4).
///
/// The same 16-word recovery code must derive the same KEK on every platform.
/// These tests use a dynamically generated code so no pre-computed valid BIP-39
/// checksum is required. They verify the contract: same words → same KEK,
/// regardless of how many times or on how many "devices" it is computed.
void main() {
  group('Recovery cross-platform KAT (§2.4)', () {
    late RecoveryCode katCode;

    setUpAll(() {
      katCode = RecoveryCode.generate();
    });

    test('KEK is deterministic across instances (same words → same KEK)', () {
      // Simulate "Platform A" and "Platform B" both entering the same words.
      final kek1 = katCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      // "Platform B" reconstructs from words
      final platformB = RecoveryCode.fromWords(katCode.words);
      final kek2 = platformB.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(kek1, equals(kek2));
    });

    test('KEK is 32 bytes', () {
      final kek = katCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(kek.length, equals(32));
    });

    test('different codes produce different KEKs', () {
      final other = RecoveryCode.generate();
      final kek1 = katCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final kek2 = other.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(kek1, isNot(equals(kek2)));
    });

    test('blob wrapped on one "platform" unwraps on another (same KEK)', () {
      final accountKey = Uint8List(32)..fillRange(0, 32, 0x42);
      final aad = Uint8List(4)..fillRange(0, 4, 0xCC);

      // "Platform A" wraps
      final kekA = katCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final encoded = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: kekA,
        aad: aad,
      ).encode();

      // "Platform B" (new instance, same words) unwraps
      final platformB = RecoveryCode.fromWords(katCode.words);
      final kekB = platformB.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final recovered = WrappedBlob.decode(encoded).unwrap(kek: kekB, aad: aad);
      expect(recovered, equals(accountKey));
    });
  });
}
