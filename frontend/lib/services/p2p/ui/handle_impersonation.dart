// §9.10 T-HDL-001 — Handle impersonation: warn when handle matches common patterns.
//
// Displays a warning when a peer's handle closely resembles an official/admin
// handle (e.g., "Admin", "ChessRecast", "Moderator") to prevent social
// engineering attacks.
library;

/// Official handle prefixes / exact matches that impersonators often mimic.
const List<String> kProtectedHandlePatterns = [
  'admin',
  'chessrecast',
  'moderator',
  'mod',
  'support',
  'official',
  'staff',
  'system',
];

/// Result of handle impersonation check.
enum HandleImpersonationRisk {
  /// Handle does not resemble any protected pattern.
  safe,

  /// Handle closely resembles a protected pattern — warn the user.
  possibleImpersonation,
}

/// Check whether [handle] matches or closely resembles a protected handle.
///
/// Matching rules (case-insensitive):
///   1. Exact match after stripping non-alphanumeric characters.
///   2. Starts with or ends with a protected pattern.
HandleImpersonationRisk evaluateHandle(String handle) {
  final normalized = handle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  for (final pattern in kProtectedHandlePatterns) {
    if (normalized == pattern ||
        normalized.startsWith(pattern) ||
        normalized.endsWith(pattern)) {
      return HandleImpersonationRisk.possibleImpersonation;
    }
  }
  return HandleImpersonationRisk.safe;
}

/// Warning message shown when possible impersonation is detected.
const String kHandleImpersonationWarning =
    'This player\'s handle resembles an official ChessRecast account. '
    'Official staff will never ask for your seed phrase or password.';
