// Proof test for roadmap leaf 8.3.b2:
// No PII in client telemetry by default; opt-in detailed mode adds session ids only.
//
// Tests the DiagRedactor utility which strips PII patterns from diagnostic
// entries before they are appended to DiagLog or exported.

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/telemetry/diag_redactor.dart';

void main() {
  group('DiagRedactor — PII redaction', () {
    test('IPv4 addresses are redacted', () {
      final r = DiagRedactor();
      expect(
        r.redact('connection from 192.168.1.42'),
        isNot(contains('192.168.1.42')),
      );
      expect(r.redact('peer=10.0.0.1:3478'), isNot(contains('10.0.0.1')));
    });

    test('IPv6 addresses are redacted', () {
      final r = DiagRedactor();
      expect(
        r.redact('ICE candidate 2001:db8::1 responded'),
        isNot(contains('2001:db8::1')),
      );
    });

    test('email addresses are redacted', () {
      final r = DiagRedactor();
      expect(
        r.redact('user: alice@example.com joined'),
        isNot(contains('alice@example.com')),
      );
    });

    test('peer public keys (64-char hex) are redacted', () {
      final r = DiagRedactor();
      final hexKey = 'a' * 64;
      expect(r.redact('peer_key=$hexKey'), isNot(contains(hexKey)));
    });

    test('non-PII content is preserved after redaction', () {
      final r = DiagRedactor();
      const entry = 'move_applied ply=12 dt_ms=5 state=playing';
      expect(r.redact(entry), equals(entry));
    });

    test(
      'session_id is NOT redacted by default (not PII in non-detailed mode)',
      () {
        // Session IDs are UUIDs and are acceptable in default mode.
        final r = DiagRedactor();
        const entry =
            'session_id=550e8400-e29b-41d4-a716-446655440000 event=start';
        // UUIDs should be preserved (they are not PII).
        expect(r.redact(entry), equals(entry));
      },
    );
  });
}
