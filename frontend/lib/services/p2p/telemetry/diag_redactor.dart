// DiagRedactor — strips PII patterns from diagnostic log entries (§8.3 / leaf 8.3.b2).
//
// Default mode (no opt-in): removes IPv4, IPv6, email addresses, and
// 64-character hex public keys from entry strings before they are stored.
//
// What is NOT redacted:
//   • Session UUIDs — these are random ephemeral IDs, not personal data.
//   • Game state strings (FEN, UCI moves) — no PII.
//   • Numeric metrics (latency, ply count) — no PII.
//
// Usage:
//   final redactor = DiagRedactor();
//   diagLog.append(redactor.redact(rawEntry));

/// Replaces PII patterns in a diagnostic log entry with placeholder tokens.
class DiagRedactor {
  // IPv4: e.g. 192.168.1.42 or 10.0.0.1:3478
  static final _ipv4 = RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b');

  // IPv6: covers full form and compressed :: notation, e.g. 2001:db8::1
  // Matches 2+ colon-delimited hex groups (each 0-4 hex digits).
  static final _ipv6 = RegExp(r'(?:[0-9a-fA-F]{0,4}:){2,8}[0-9a-fA-F]{0,4}');

  // Email addresses
  static final _email = RegExp(
    r'\b[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}\b',
  );

  // 64-char lowercase/uppercase hex strings (Ed25519 public key size)
  static final _hex64 = RegExp(r'\b[0-9a-fA-F]{64}\b');

  /// Returns [entry] with all recognised PII patterns replaced by tokens.
  String redact(String entry) {
    return entry
        .replaceAll(_email, '[EMAIL]')
        .replaceAll(_hex64, '[KEY]')
        .replaceAll(_ipv6, '[IPv6]')
        .replaceAll(_ipv4, '[IPv4]');
  }
}
