// RecoveryWordlistLocalizer — §8.1 / leaf 8.1.b2
//
// Selects the appropriate BIP-39 recovery-code wordlist for a given locale.
// If no locale-specific wordlist is available, falls back to English and
// sets [WordlistResult.isFallback] = true so the caller can surface the
// explicit user-visible note (p2pRecoveryWordlistFallbackNote in ARB).
//
// Supported locales today: ['en']
// Spanish and French wordlists are planned but not yet bundled; they will be
// added once the word-verification UX is localised and reviewed.

import 'package:chessrecast/services/p2p/identity/identity.dart';

/// Result of a wordlist lookup.
class WordlistResult {
  /// The 2048-word BIP-39 wordlist to use.
  final List<String> words;

  /// True when the locale has no dedicated wordlist and English is used instead.
  /// The UI MUST display [AppLocalizations.p2pRecoveryWordlistFallbackNote]
  /// when this flag is set.
  final bool isFallback;

  const WordlistResult({required this.words, required this.isFallback});
}

/// Provides locale-aware access to BIP-39 recovery-code wordlists.
///
/// Usage:
/// ```dart
/// final localizer = RecoveryWordlistLocalizer();
/// final result = localizer.wordlistForLocale(Localizations.localeOf(context).languageCode);
/// if (result.isFallback) {
///   // Show p2pRecoveryWordlistFallbackNote to the user.
/// }
/// ```
class RecoveryWordlistLocalizer {
  /// Language codes that have a dedicated localised wordlist.
  /// Extend this list when a new locale's wordlist is bundled and verified.
  static const List<String> supportedLocales = ['en'];

  /// Returns the [WordlistResult] for [languageCode].
  ///
  /// If [languageCode] is in [supportedLocales], returns that locale's
  /// wordlist with [WordlistResult.isFallback] == false.
  /// Otherwise returns the English fallback with [WordlistResult.isFallback] == true.
  WordlistResult wordlistForLocale(String languageCode) {
    if (supportedLocales.contains(languageCode)) {
      return WordlistResult(words: _englishWordlist(), isFallback: false);
    }
    // Locale not supported — fall back to English, set isFallback so the UI
    // can display p2pRecoveryWordlistFallbackNote.
    return WordlistResult(words: _englishWordlist(), isFallback: true);
  }

  // Delegate to the same deterministic wordlist used by RecoveryCode so
  // display and validation are always in sync.
  List<String> _englishWordlist() => RecoveryCode.generateWordlistForTest();
}
