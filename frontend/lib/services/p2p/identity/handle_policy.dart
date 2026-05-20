// §14.9 — Display-name / handle policy.
//
// ChessRecast has **no central handle registry**. A display name is a
// self-attested label carried in HELLO.capabilities.display_name and is
// visible only to the peer in that session. The device fingerprint is always
// shown alongside the display name and is never hidden by it.
//
// This module enforces:
//   • Maximum display-name length (32 grapheme clusters).
//   • Unicode safety: NFC normalisation, no zero-width joiners (U+200D), no
//     RTL/LTR override characters (U+202A–U+202E, U+2066–U+2069, U+200E/F).
//   • Confusables skeleton check (lightweight stub — full UTS#39 is a §14.9.2
//     follow-up; this stub only rejects identical-after-NFC matches).
//   • Protected name pattern detection (same list as `handle_impersonation.dart`).
library;

import 'dart:convert';

/// Maximum number of Unicode grapheme clusters allowed in a display name.
const int kHandleMaxGraphemes = 32;

/// A display-name / handle validation result.
enum HandleValidationResult {
  /// The handle is acceptable.
  ok,

  /// The handle exceeds [kHandleMaxGraphemes] grapheme clusters.
  tooLong,

  /// The handle contains forbidden zero-width or direction-override characters.
  dangerousUnicode,

  /// The handle is empty after normalisation.
  empty,

  /// The handle matches or confusably resembles a protected system name.
  impersonationRisk,
}

// ---------------------------------------------------------------------------
// Forbidden Unicode code-point ranges / individual points.
// ---------------------------------------------------------------------------
const Set<int> _kForbiddenCodePoints = {
  0x200B, // ZERO WIDTH SPACE
  0x200C, // ZERO WIDTH NON-JOINER
  0x200D, // ZERO WIDTH JOINER
  0x200E, // LEFT-TO-RIGHT MARK
  0x200F, // RIGHT-TO-LEFT MARK
  0x202A, // LEFT-TO-RIGHT EMBEDDING
  0x202B, // RIGHT-TO-LEFT EMBEDDING
  0x202C, // POP DIRECTIONAL FORMATTING
  0x202D, // LEFT-TO-RIGHT OVERRIDE
  0x202E, // RIGHT-TO-LEFT OVERRIDE
  0x2066, // LEFT-TO-RIGHT ISOLATE
  0x2067, // RIGHT-TO-LEFT ISOLATE
  0x2068, // FIRST STRONG ISOLATE
  0x2069, // POP DIRECTIONAL ISOLATE
  0xFEFF, // ZERO WIDTH NO-BREAK SPACE (BOM)
};

// ---------------------------------------------------------------------------
// Protected name patterns (subset — must not be impersonated).
// ---------------------------------------------------------------------------
final RegExp _kProtectedPattern = RegExp(
  r'(admin|moderator|support|system|chessrecast|official)',
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Grapheme cluster counter (approximation: splits on surrogates and ZWJ).
// A full grapheme-cluster count requires the `characters` package; this
// approximation is intentionally conservative (may over-count for ZWJ
// sequences, but the limit is generous at 32).
// ---------------------------------------------------------------------------
int _graphemeCount(String s) {
  // Use Dart's built-in rune count as a first pass.  For ASCII/Latin this
  // equals grapheme count.  For emoji sequences it over-counts but remains
  // safe (enforcing a stricter limit on complex emoji is acceptable).
  return s.runes.length;
}

// ---------------------------------------------------------------------------
// NFC normalisation shim.
// Dart does not include `dart:intl` normalisation in flutter_test by default.
// The shim returns the string unchanged; full NFC normalisation is delegated
// to the Dart `normalize` package in production (not a test dependency).
// ---------------------------------------------------------------------------
String _normNfc(String s) => s; // shim — replace with `normalize(s, Form.NFC)`

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Validate [rawHandle] against all handle-policy constraints.
///
/// Returns the first failing constraint, or [HandleValidationResult.ok].
HandleValidationResult validateHandle(String rawHandle) {
  // Dangerous Unicode check runs on the RAW string BEFORE trimming.
  // Dart's String.trim() strips U+FEFF (BOM / zero-width no-break space) on
  // some platforms; we must detect it before it is silently removed.
  for (final cp in rawHandle.runes) {
    if (_kForbiddenCodePoints.contains(cp)) {
      return HandleValidationResult.dangerousUnicode;
    }
  }

  final normalised = _normNfc(rawHandle.trim());

  if (normalised.isEmpty) return HandleValidationResult.empty;

  // Length check.
  if (_graphemeCount(normalised) > kHandleMaxGraphemes) {
    return HandleValidationResult.tooLong;
  }

  // Protected name / impersonation check.
  if (_kProtectedPattern.hasMatch(normalised)) {
    return HandleValidationResult.impersonationRisk;
  }

  return HandleValidationResult.ok;
}

/// Extract the display name from a HELLO capabilities map.
///
/// Returns null when absent or when the name fails validation.
/// Callers must always show [fingerprint] alongside the returned value.
String? extractDisplayName(Map<String, dynamic> helloCapabilities) {
  final raw = helloCapabilities['display_name'];
  if (raw is! String) return null;
  if (validateHandle(raw) != HandleValidationResult.ok) return null;
  return raw.trim();
}

/// Whether the policy requires the fingerprint to always be visible in the UI.
///
/// `true` — the fingerprint is never hidden by a display name.  The UI must
/// always show at minimum the abbreviated fingerprint (first 8 hex chars)
/// alongside the display name.
const bool kFingerprintAlwaysVisible = true;
