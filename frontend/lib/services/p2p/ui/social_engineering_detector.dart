// §14.6 — Social engineering / phishing detector for in-game chat.
//
// Detects patterns commonly used to social-engineer a chess opponent:
//   - Recovery phrase / seed phrase solicitation.
//   - Password request.
//   - URL shorteners that obscure the real destination.
//   - Credential-harvesting phrases ("send me your …").
//   - 12/24-word mnemonic patterns (crypto seed phrases).
//
// The detector is applied to incoming messages before rendering and to
// outgoing messages before sending (with a softer UX for outgoing).
library;

/// The class of social-engineering pattern detected.
enum SocialEngineeringKind {
  /// A URL shortener was found in the message.
  urlShortener,

  /// A seed/recovery phrase request was found.
  seedPhraseRequest,

  /// A password/credential request was found.
  passwordRequest,

  /// A credential-harvest phrase ("send me your …") was found.
  credentialHarvestPhrase,

  /// A bare 12-word or 24-word mnemonic sequence was found.
  mnemonicSequence,
}

/// Result of scanning a single chat message.
class SocialEngineeringDetectionResult {
  /// Whether any pattern was found.
  final bool detected;

  /// The kind of pattern detected (null when [detected] is false).
  final SocialEngineeringKind? kind;

  /// The matched substring from the message.
  final String? matchedSubstring;

  const SocialEngineeringDetectionResult._({
    required this.detected,
    this.kind,
    this.matchedSubstring,
  });

  /// No pattern detected.
  static const SocialEngineeringDetectionResult clean =
      SocialEngineeringDetectionResult._(detected: false);

  factory SocialEngineeringDetectionResult.match({
    required SocialEngineeringKind kind,
    required String matched,
  }) => SocialEngineeringDetectionResult._(
    detected: true,
    kind: kind,
    matchedSubstring: matched,
  );
}

/// Chat message direction (important for UX copy on detection).
enum MessageDirection {
  /// Message was received from the opponent.
  incoming,

  /// Message is being composed / sent by the local user.
  outgoing,
}

// ---------------------------------------------------------------------------
// Known URL shorteners (conservative list of high-abuse domains).
// ---------------------------------------------------------------------------
const List<String> _kUrlShortenerDomains = [
  'bit.ly',
  'tinyurl.com',
  't.co',
  'goo.gl',
  'ow.ly',
  'is.gd',
  'buff.ly',
  'rebrand.ly',
  'short.link',
  'cutt.ly',
  'tr.im',
  'bl.ink',
  'tiny.cc',
  'snip.ly',
];

// ---------------------------------------------------------------------------
// Seed / recovery phrase keywords.
// ---------------------------------------------------------------------------
final RegExp _kSeedPhrasePattern = RegExp(
  r'\b(seed\s+phrase|recovery\s+phrase|mnemonic|backup\s+phrase|secret\s+phrase)\b',
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Password keywords.
// ---------------------------------------------------------------------------
final RegExp _kPasswordPattern = RegExp(
  r'\b(password|passphrase|pass\s*code|pin)\b',
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Credential-harvest openers.
// ---------------------------------------------------------------------------
final RegExp _kCredentialHarvestPattern = RegExp(
  r'\bsend\s+(me\s+)?your\s+(password|seed|phrase|key|mnemonic|private\s+key|wallet)\b',
  caseSensitive: false,
);

// ---------------------------------------------------------------------------
// Mnemonic sequence: 12 or 24 lowercase dictionary words separated by spaces.
// This is an approximation; a full BIP-39 wordlist check is out of scope.
// ---------------------------------------------------------------------------
final RegExp _kMnemonicPattern = RegExp(
  r'\b([a-z]{3,8}\s+){11}[a-z]{3,8}\b|\b([a-z]{3,8}\s+){23}[a-z]{3,8}\b',
  caseSensitive: false,
);

/// Scans [message] for social-engineering patterns.
///
/// Returns the first detection result. If multiple patterns match, the most
/// severe is returned (credential-harvest > seed > password > mnemonic > url).
SocialEngineeringDetectionResult scanMessage(String message) {
  // 1. Credential-harvest (highest severity).
  final harvestMatch = _kCredentialHarvestPattern.firstMatch(message);
  if (harvestMatch != null) {
    return SocialEngineeringDetectionResult.match(
      kind: SocialEngineeringKind.credentialHarvestPhrase,
      matched: harvestMatch.group(0)!,
    );
  }

  // 2. Seed / recovery phrase.
  final seedMatch = _kSeedPhrasePattern.firstMatch(message);
  if (seedMatch != null) {
    return SocialEngineeringDetectionResult.match(
      kind: SocialEngineeringKind.seedPhraseRequest,
      matched: seedMatch.group(0)!,
    );
  }

  // 3. Password/passphrase.
  final pwMatch = _kPasswordPattern.firstMatch(message);
  if (pwMatch != null) {
    return SocialEngineeringDetectionResult.match(
      kind: SocialEngineeringKind.passwordRequest,
      matched: pwMatch.group(0)!,
    );
  }

  // 4. Mnemonic sequence.
  final mnemonicMatch = _kMnemonicPattern.firstMatch(message);
  if (mnemonicMatch != null) {
    return SocialEngineeringDetectionResult.match(
      kind: SocialEngineeringKind.mnemonicSequence,
      matched: mnemonicMatch.group(0)!,
    );
  }

  // 5. URL shortener.
  final lowerMessage = message.toLowerCase();
  for (final domain in _kUrlShortenerDomains) {
    if (lowerMessage.contains(domain)) {
      return SocialEngineeringDetectionResult.match(
        kind: SocialEngineeringKind.urlShortener,
        matched: domain,
      );
    }
  }

  return SocialEngineeringDetectionResult.clean;
}

/// Returns the warning message to display based on detection kind and direction.
///
/// URLs in chat are NEVER auto-clickable. The UI must always surface a
/// "Reveal link" action gated by [kRequireRevealForLinks] = true before
/// following any URL — shortened or otherwise.
String warningCopyFor({
  required SocialEngineeringKind kind,
  required MessageDirection direction,
}) {
  switch (kind) {
    case SocialEngineeringKind.urlShortener:
      return direction == MessageDirection.incoming
          ? 'This message contains a shortened link. Shortened links can hide '
                'dangerous websites. Do not tap it — use "Reveal link" to inspect '
                'the destination first.'
          : 'Your message contains a shortened link. Are you sure you want to '
                'send it? Shortened links look suspicious to your opponent.';
    case SocialEngineeringKind.seedPhraseRequest:
    case SocialEngineeringKind.credentialHarvestPhrase:
      return direction == MessageDirection.incoming
          ? 'Warning: this message asks for sensitive information (seed phrase / '
                'recovery phrase). Never share this with anyone.'
          : 'Your message appears to ask for sensitive information. Are you sure?';
    case SocialEngineeringKind.passwordRequest:
      return direction == MessageDirection.incoming
          ? 'Warning: this message asks for a password. Legitimate services '
                'never ask for passwords over chat.'
          : 'Your message appears to ask for a password. Are you sure?';
    case SocialEngineeringKind.mnemonicSequence:
      return direction == MessageDirection.incoming
          ? 'This message may contain a wallet recovery phrase. Do not enter '
                'these words anywhere.'
          : 'Your message may contain a recovery phrase. Are you sure you want '
                'to send it?';
  }
}

/// Whether the UI must always gate link-following behind a "Reveal link" tap.
const bool kRequireRevealForLinks = true;
