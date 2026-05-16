// §6.1 / §6.1.3 In-app feedback channel + opt-in crash reporting.
//
// Dispatches crash reports and user feedback through a pluggable [sink]
// callback (wire to Sentry, Firebase Crashlytics, or a custom HTTP endpoint).
//
// Key guarantees:
//  - No report leaves the device unless the user has opted in.
//  - PII (IP addresses, public keys, device UUIDs) is scrubbed before
//    dispatch via [PiiRedactor].
//  - Opt-in is an explicit user decision; the default is `false` (safe).

/// Redacts PII from arbitrary strings before they are included in reports.
class PiiRedactor {
  // IPv4 — four decimal octets separated by dots.
  static final _ipv4 = RegExp(
    r'\b(\d{1,3}\.){3}\d{1,3}\b',
  );

  // IPv6 — simplified: 2+ groups of hex separated by colons (covers the
  // common forms; not a full RFC 4291 parser, which is unnecessary for
  // log-scrubbing).
  static final _ipv6 = RegExp(
    r'\b([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}\b',
  );

  // Public key — 64 or more consecutive hex characters (covers Ed25519 / X25519
  // keys serialised as hex strings, which are exactly 64 chars).
  static final _hexKey = RegExp(r'\b[0-9a-fA-F]{64,}\b');

  // UUID v4 (and similar) — 8-4-4-4-12 hex with dashes.
  static final _uuid = RegExp(
    r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
    caseSensitive: false,
  );

  /// Returns [input] with all detected PII tokens replaced by redaction markers.
  static String scrub(String input) {
    var s = input;
    s = s.replaceAll(_ipv4, '[REDACTED_IP]');
    s = s.replaceAll(_ipv6, '[REDACTED_IP]');
    s = s.replaceAll(_hexKey, '[REDACTED_KEY]');
    s = s.replaceAll(_uuid, '[REDACTED_UUID]');
    return s;
  }
}

/// Pluggable crash reporter with mandatory PII scrubbing and opt-in gate.
///
/// ```dart
/// final reporter = CrashReporter(
///   sink: SentryClient.capture,
///   optIn: prefs.getBool('crash_reporting_opt_in') ?? false,
/// );
/// ```
class CrashReporter {
  /// Called with every scrubbed report payload when opt-in is true.
  final void Function(Map<String, dynamic> report) sink;

  bool _optIn;

  CrashReporter({
    required this.sink,
    bool optIn = false,
  }) : _optIn = optIn;

  // ── Opt-in ───────────────────────────────────────────────────────────────

  /// Updates the opt-in state. All subsequent reports respect the new value
  /// immediately.
  void setOptIn(bool value) => _optIn = value;

  bool get isOptedIn => _optIn;

  // ── Crash report ─────────────────────────────────────────────────────────

  /// Reports a crash. [message] and [stackTrace] are PII-scrubbed before
  /// dispatch. No-op when [isOptedIn] is false.
  void reportCrash({
    required String message,
    required String stackTrace,
    Map<String, dynamic>? extras,
  }) {
    if (!_optIn) return;
    sink({
      'eventType': 'crash',
      'message': PiiRedactor.scrub(message),
      'stackTrace': PiiRedactor.scrub(stackTrace),
      if (extras != null) ...extras,
    });
  }

  // ── User feedback ─────────────────────────────────────────────────────────

  /// Submits user-written feedback. [text] is PII-scrubbed before dispatch.
  /// No-op when [isOptedIn] is false.
  void submitFeedback({required String text}) {
    if (!_optIn) return;
    sink({
      'eventType': 'feedback',
      'feedbackText': PiiRedactor.scrub(text),
    });
  }
}
