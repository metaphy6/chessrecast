import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('RecoveryCode — BIP-39 checksum (§2.2)', () {
    test('valid code passes checksum', () {
      final code = RecoveryCode.generate();
      // Should not throw
      final reconstructed = RecoveryCode.fromWords(code.words);
      expect(reconstructed.words, equals(code.words));
    });

    test('unknown word throws ArgumentError', () {
      final code = RecoveryCode.generate();
      final badWords = List<String>.from(code.words);
      badWords[7] = 'xxxxxxxxxxxxxxxx_not_in_bip39';
      expect(
        () => RecoveryCode.fromWords(badWords),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'single-word substitution from another code triggers checksum error',
      () {
        // Try multiple pairs to account for rare same-index match
        bool checkedAtLeastOne = false;
        for (int attempt = 0; attempt < 10; attempt++) {
          final codeA = RecoveryCode.generate();
          final codeB = RecoveryCode.generate();
          final words = List<String>.from(codeA.words);
          // Replace word at index 5 with codeB's word at index 5 (if different)
          if (codeB.words[5] != codeA.words[5]) {
            words[5] = codeB.words[5];
            expect(
              () => RecoveryCode.fromWords(words),
              throwsA(isA<Bip39ChecksumError>()),
              reason: 'Checksum should fail when entropy bits are changed',
            );
            checkedAtLeastOne = true;
            break;
          }
        }
        // If we couldn't generate a different word at index 5, skip gracefully.
        // This is astronomically unlikely with the wordlist size.
      },
    );

    test('empty word list throws ArgumentError', () {
      expect(() => RecoveryCode.fromWords([]), throwsA(isA<ArgumentError>()));
    });

    test('17 words throws ArgumentError', () {
      final code = RecoveryCode.generate();
      expect(
        () => RecoveryCode.fromWords([...code.words, code.words[0]]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
