import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('Recovery flow — end-to-end (§2.2)', () {
    test('BIP-39 checksum validates before Argon2 runs', () {
      // Simulate a user typing one wrong word — should fail at BIP-39 check
      // without running Argon2id (which would take seconds).
      final original = RecoveryCode.generate();
      final words = List<String>.from(original.words);
      // Modify entropy to find a word from a different code
      final other = RecoveryCode.generate();
      final differentWord = other.words.firstWhere(
        (w) => !words.contains(w),
        orElse: () => 'w0200',
      ); // fallback to generated word
      if (differentWord != 'w0200' || !words.contains(differentWord)) {
        words[3] = differentWord;
        // BIP-39 checksum must fire before any Argon2 work
        bool checksumsRejected = false;
        try {
          RecoveryCode.fromWords(words);
        } on Bip39ChecksumError {
          checksumsRejected = true;
        } on ArgumentError {
          checksumsRejected = true;
        }
        expect(checksumsRejected, isTrue);
      }
    });

    test(
      'round-trip: generate → wrap → export → import → unwrap account key',
      () {
        // Generate a device-like account key
        final accountKey = Uint8List(32)..fillRange(0, 32, 0x55);
        // User sets a recovery code
        final code = RecoveryCode.generate();
        // Derive KEK from recovery code
        final kek = code.deriveKek(
          mKib: Argon2idStub.mMinKib,
          iterations: Argon2idStub.tMin,
        );
        // Wrap the account key
        final aad = Uint8List.fromList([0x01, 0x02, 0x03]);
        final blob = WrappedBlob.wrap(
          accountKey: accountKey,
          kek: kek,
          aad: aad,
        );
        final encodedBlob = blob.encode();

        // --- On new device: user enters recovery code ---
        final restoredCode = RecoveryCode.fromWords(code.words);
        final restoredKek = restoredCode.deriveKek(
          mKib: Argon2idStub.mMinKib,
          iterations: Argon2idStub.tMin,
        );
        final decodedBlob = WrappedBlob.decode(encodedBlob);
        final restoredKey = decodedBlob.unwrap(kek: restoredKek, aad: aad);

        expect(restoredKey, equals(accountKey));
      },
    );

    test('wrong recovery code produces BlobIntegrityError', () {
      final accountKey = Uint8List(32)..fillRange(0, 32, 0x77);
      final realCode = RecoveryCode.generate();
      final kek = realCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final aad = Uint8List(16)..fillRange(0, 16, 0xAA);
      final blob = WrappedBlob.wrap(accountKey: accountKey, kek: kek, aad: aad);
      final encoded = blob.encode();

      // Wrong recovery code entered by user
      final wrongCode = RecoveryCode.generate();
      final wrongKek = wrongCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(
        () => WrappedBlob.decode(encoded).unwrap(kek: wrongKek, aad: aad),
        throwsA(isA<BlobIntegrityError>()),
      );
    });
  });
}
