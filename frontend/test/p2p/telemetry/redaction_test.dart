// §6.1 / §6.1.3 In-app feedback + opt-in crash reporting PII-redaction proof.
//
// Verifies that:
//  - No crash report is dispatched when opt-in is false (default).
//  - With opt-in, a scrubbed report is dispatched (no PII fields).
//  - PII-bearing fields (IP addresses, pub-keys, peer-ids, device UUIDs) are
//    redacted before the report leaves the device.
//  - The in-app feedback submission also scrubs PII from the body text.
//  - Opt-in state can be toggled and is respected immediately.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/telemetry/crash_reporter.dart';

void main() {
  group('CrashReporter §6.1 opt-in and PII redaction', () {
    late List<Map<String, dynamic>> dispatched;
    late CrashReporter reporter;

    setUp(() {
      dispatched = [];
      reporter = CrashReporter(
        sink: (report) => dispatched.add(report),
        optIn: false,
      );
    });

    // ── Opt-in guard ────────────────────────────────────────────────────────
    test('no report dispatched when opt-in is false (default)', () {
      reporter.reportCrash(
        message: 'NullPointerException in session.dart:42',
        stackTrace: 'session.dart 42\nidentity.dart 88',
      );
      expect(dispatched, isEmpty);
    });

    test('report is dispatched when opt-in is true', () {
      reporter.setOptIn(true);
      reporter.reportCrash(
        message: 'NullPointerException in session.dart:42',
        stackTrace: 'session.dart 42',
      );
      expect(dispatched, hasLength(1));
    });

    test('toggling opt-in off stops further reports', () {
      reporter.setOptIn(true);
      reporter.reportCrash(message: 'err1', stackTrace: '');
      reporter.setOptIn(false);
      reporter.reportCrash(message: 'err2', stackTrace: '');
      expect(dispatched, hasLength(1));
    });

    // ── PII redaction in crash reports ─────────────────────────────────────
    test('IPv4 addresses are redacted from message', () {
      reporter.setOptIn(true);
      reporter.reportCrash(
        message: 'ICE candidate failed from 192.168.1.50',
        stackTrace: '',
      );
      expect(dispatched.first['message'], isNot(contains('192.168.1.50')));
      expect(dispatched.first['message'], contains('[REDACTED_IP]'));
    });

    test('IPv6 addresses are redacted from stack trace', () {
      reporter.setOptIn(true);
      reporter.reportCrash(
        message: 'error',
        stackTrace: 'connect to 2001:db8::1 failed',
      );
      expect(dispatched.first['stackTrace'], isNot(contains('2001:db8::1')));
      expect(dispatched.first['stackTrace'], contains('[REDACTED_IP]'));
    });

    test('public-key hex strings (64+ hex chars) are redacted', () {
      reporter.setOptIn(true);
      final pubkey = 'a' * 64;
      reporter.reportCrash(
        message: 'key exchange failed: pubkey=$pubkey',
        stackTrace: '',
      );
      expect(dispatched.first['message'], isNot(contains(pubkey)));
      expect(dispatched.first['message'], contains('[REDACTED_KEY]'));
    });

    test('device UUID strings are redacted', () {
      reporter.setOptIn(true);
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      reporter.reportCrash(
        message: 'device=$uuid crashed',
        stackTrace: '',
      );
      expect(dispatched.first['message'], isNot(contains(uuid)));
      expect(dispatched.first['message'], contains('[REDACTED_UUID]'));
    });

    // ── Feedback channel ───────────────────────────────────────────────────
    test('feedback submission is blocked when opt-in is false', () {
      reporter.submitFeedback(text: 'My IP is 10.0.0.1');
      expect(dispatched, isEmpty);
    });

    test('feedback PII is redacted before dispatch', () {
      reporter.setOptIn(true);
      reporter.submitFeedback(text: 'I get errors, my IP is 10.0.0.1');
      expect(dispatched, hasLength(1));
      expect(dispatched.first['feedbackText'], isNot(contains('10.0.0.1')));
      expect(dispatched.first['feedbackText'], contains('[REDACTED_IP]'));
    });

    test('report includes a non-null event-type field', () {
      reporter.setOptIn(true);
      reporter.reportCrash(message: 'crash', stackTrace: '');
      expect(dispatched.first['eventType'], isNotNull);
    });

    test('feedback event type is distinct from crash event type', () {
      reporter.setOptIn(true);
      reporter.reportCrash(message: 'crash', stackTrace: '');
      reporter.submitFeedback(text: 'feedback');
      expect(
        dispatched[0]['eventType'],
        isNot(equals(dispatched[1]['eventType'])),
      );
    });
  });
}
