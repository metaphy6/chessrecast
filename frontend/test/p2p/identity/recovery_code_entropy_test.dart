import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('RecoveryCode — BIP-39 entropy & generation (§2.2)', () {
    test('generate() returns 16 words', () {
      final code = RecoveryCode.generate();
      expect(code.words.length, equals(16));
    });

    test('generate() produces unique codes each call', () {
      final c1 = RecoveryCode.generate();
      final c2 = RecoveryCode.generate();
      expect(c1.words, isNot(equals(c2.words)));
    });

    test('entropy is 21 bytes (165 bits, zero-padded)', () {
      final code = RecoveryCode.generate();
      expect(code.entropy.length, equals(21));
    });

    test('round-trip: fromWords reconstructs the same entropy', () {
      final original = RecoveryCode.generate();
      final reconstructed = RecoveryCode.fromWords(original.words);
      expect(reconstructed.entropy, equals(original.entropy));
      expect(reconstructed.words, equals(original.words));
    });

    test('fromWords throws Bip39ChecksumError on tampered word', () {
      final code = RecoveryCode.generate();
      final words = List<String>.from(code.words);
      // Replace the first word with one that breaks the checksum.
      // Find a different word from the wordlist that is valid but changes entropy.
      final otherCode = RecoveryCode.generate();
      words[0] = otherCode.words[0] != words[0]
          ? otherCode.words[0]
          : otherCode.words[1];
      // Only run if the substituted word is actually different.
      if (words[0] != code.words[0]) {
        expect(
          () => RecoveryCode.fromWords(words),
          throwsA(isA<Bip39ChecksumError>()),
        );
      }
    });

    test('words.length != 16 throws ArgumentError', () {
      expect(
        () => RecoveryCode.fromWords(['word']),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deriveKek produces 32-byte output', () {
      final code = RecoveryCode.generate();
      final kek = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(kek.length, equals(32));
    });

    test('deriveKek is deterministic for the same recovery code', () {
      final code = RecoveryCode.generate();
      final kek1 = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final kek2 = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(kek1, equals(kek2));
    });

    test('deriveKek differs between different recovery codes', () {
      final c1 = RecoveryCode.generate();
      final c2 = RecoveryCode.generate();
      final kek1 = c1.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final kek2 = c2.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(kek1, isNot(equals(kek2)));
    });
  });
}
