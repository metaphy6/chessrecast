// Proof test for roadmap leaf 8.1.b2:
// Recovery-code wordlist localised — fallback to English if a locale wordlist
// is unavailable, with explicit user-visible note.
//
// Tests the RecoveryWordlistLocalizer service which selects the appropriate
// locale wordlist and signals when the English fallback is in use.

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/identity/recovery_wordlist_localizer.dart';

void main() {
  group('RecoveryWordlistLocalizer', () {
    test('returns English wordlist for locale "en"', () {
      final localizer = RecoveryWordlistLocalizer();
      final result = localizer.wordlistForLocale('en');
      expect(result.words, hasLength(2048));
      expect(result.isFallback, isFalse);
      expect(result.words.first, equals('abandon'));
    });

    test('returns fallback (English) wordlist for unsupported locale', () {
      final localizer = RecoveryWordlistLocalizer();
      final result = localizer.wordlistForLocale('zh');
      expect(result.words, hasLength(2048));
      expect(result.isFallback, isTrue,
          reason: 'Chinese locale is not yet supported; must use English fallback');
    });

    test('isFallback is false for all supported locales', () {
      final localizer = RecoveryWordlistLocalizer();
      for (final locale in RecoveryWordlistLocalizer.supportedLocales) {
        final result = localizer.wordlistForLocale(locale);
        expect(result.isFallback, isFalse,
            reason: 'Locale "$locale" is listed as supported but returned isFallback=true');
      }
    });

    test('fallback wordlist equals English wordlist', () {
      final localizer = RecoveryWordlistLocalizer();
      final en = localizer.wordlistForLocale('en');
      final fallback = localizer.wordlistForLocale('xx_UNSUPPORTED');
      expect(fallback.words, equals(en.words));
    });

    test('wordlist contains exactly 2048 unique words', () {
      final localizer = RecoveryWordlistLocalizer();
      final result = localizer.wordlistForLocale('en');
      final unique = result.words.toSet();
      expect(unique.length, equals(2048),
          reason: 'Wordlist must have 2048 unique entries (no duplicates)');
    });
  });
}
