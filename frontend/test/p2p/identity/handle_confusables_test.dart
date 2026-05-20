// §14.9 — Handle confusables / homoglyph detection proof test.
//
// Verifies that the handle policy:
//   1. Rejects known impersonation patterns (exact-match after NFC).
//   2. Rejects dangerous Unicode (zero-width, direction-override characters).
//   3. Correctly validates legitimate handles.
//   4. Respects the 32-grapheme-cluster limit.
//
// NOTE: Full confusables skeleton algorithm (UTS#39) is a §14.9.2 follow-up.
// These tests cover what the v1 implementation guarantees.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/handle_policy.dart';

void main() {
  group('§14.9 — Handle validation', () {
    group('valid handles', () {
      test('simple ASCII name is ok', () {
        expect(validateHandle('AliceB'), equals(HandleValidationResult.ok));
      });

      test('name with spaces is ok', () {
        expect(
          validateHandle('Chess Player'),
          equals(HandleValidationResult.ok),
        );
      });

      test('name with numbers is ok', () {
        expect(validateHandle('Player42'), equals(HandleValidationResult.ok));
      });

      test('name with emoji is ok (within grapheme limit)', () {
        expect(
          validateHandle('Cool ♟ Player'),
          equals(HandleValidationResult.ok),
        );
      });

      test('exactly 32 ASCII characters is ok', () {
        final name = 'A' * 32;
        expect(validateHandle(name), equals(HandleValidationResult.ok));
      });
    });

    group('tooLong', () {
      test('33 ASCII characters fails length check', () {
        final name = 'A' * 33;
        expect(validateHandle(name), equals(HandleValidationResult.tooLong));
      });

      test('kHandleMaxGraphemes constant is 32', () {
        expect(kHandleMaxGraphemes, equals(32));
      });
    });

    group('empty', () {
      test('empty string is rejected', () {
        expect(validateHandle(''), equals(HandleValidationResult.empty));
      });

      test('whitespace-only string is rejected', () {
        expect(validateHandle('   '), equals(HandleValidationResult.empty));
      });
    });

    group('dangerousUnicode', () {
      test('zero-width joiner (U+200D) is rejected', () {
        // Zero-width joiner is commonly used to compose emoji sequences but
        // also abused to create visually identical strings.
        const zwj = '\u200D';
        expect(
          validateHandle('Alice${zwj}Bob'),
          equals(HandleValidationResult.dangerousUnicode),
        );
      });

      test('RTL override (U+202E) is rejected', () {
        const rtlOverride = '\u202E';
        expect(
          validateHandle('Chess${rtlOverride}Player'),
          equals(HandleValidationResult.dangerousUnicode),
        );
      });

      test('LTR embedding (U+202A) is rejected', () {
        const ltrEmbed = '\u202A';
        expect(
          validateHandle('${ltrEmbed}Admin'),
          equals(HandleValidationResult.dangerousUnicode),
        );
      });

      test('zero-width no-break space / BOM (U+FEFF) is rejected', () {
        const bom = '\uFEFF';
        expect(
          validateHandle('${bom}Player'),
          equals(HandleValidationResult.dangerousUnicode),
        );
      });

      test('zero-width space (U+200B) is rejected', () {
        const zws = '\u200B';
        expect(
          validateHandle('A${zws}B'),
          equals(HandleValidationResult.dangerousUnicode),
        );
      });
    });

    group('impersonationRisk (protected names)', () {
      test('"admin" is rejected', () {
        expect(
          validateHandle('admin'),
          equals(HandleValidationResult.impersonationRisk),
        );
      });

      test('"Admin" (mixed case) is rejected', () {
        expect(
          validateHandle('Admin'),
          equals(HandleValidationResult.impersonationRisk),
        );
      });

      test('"chessrecast" is rejected', () {
        expect(
          validateHandle('chessrecast'),
          equals(HandleValidationResult.impersonationRisk),
        );
      });

      test('"moderator123" is rejected', () {
        expect(
          validateHandle('moderator123'),
          equals(HandleValidationResult.impersonationRisk),
        );
      });

      test('"TheOfficialBot" is rejected (contains "official")', () {
        expect(
          validateHandle('TheOfficialBot'),
          equals(HandleValidationResult.impersonationRisk),
        );
      });

      test('"support_team" is rejected', () {
        expect(
          validateHandle('support_team'),
          equals(HandleValidationResult.impersonationRisk),
        );
      });

      // NOTE: Cyrillic homoglyph "аdmin" (Cyrillic 'а' + Latin 'dmin') is
      // intentionally NOT rejected by v1 — see §14.9.2 for the UTS#39 follow-up.
      // This test documents the known gap so it is not silently ignored.
      test(
        'Cyrillic homoglyph of "admin" is NOT rejected by v1 (known gap § 14.9.2)',
        () {
          // U+0430 is Cyrillic 'а'; the rest is Latin.
          const cyrillicA = '\u0430';
          final homoglyph = '${cyrillicA}dmin';
          // v1 does not catch this — the test documents it will fail when UTS#39 is added.
          final result = validateHandle(homoglyph);
          // The test asserts the *current* behaviour, not the desired future behaviour.
          expect(
            result,
            isNot(HandleValidationResult.impersonationRisk),
            reason:
                'v1 does not implement confusables skeleton — this gap is tracked in §14.9.2',
          );
        },
      );
    });

    group('extractDisplayName()', () {
      test('valid display_name is extracted', () {
        expect(extractDisplayName({'display_name': 'Alice'}), equals('Alice'));
      });

      test('missing display_name returns null', () {
        expect(extractDisplayName({}), isNull);
      });

      test('non-string display_name returns null', () {
        expect(extractDisplayName({'display_name': 42}), isNull);
      });

      test('invalid display_name returns null', () {
        expect(extractDisplayName({'display_name': 'admin'}), isNull);
      });
    });
  });

  group('§14.9 — kFingerprintAlwaysVisible policy constant', () {
    test('kFingerprintAlwaysVisible is true', () {
      expect(kFingerprintAlwaysVisible, isTrue);
    });
  });
}
