// §4.9 Restricted background mode session cap test.
//
// In restricted-background mode (e.g. Android data saver + aggressive OEM),
// sessions should be capped at maxRestrictedSessionSeconds.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/oem_lifecycle_policy.dart';

void main() {
  group('RestrictedModeSessionCap §4.9', () {
    test('maxRestrictedSessionSeconds is 300 (5 min)', () {
      expect(RestrictedModeSessionCap.maxRestrictedSessionSeconds, equals(300));
    });

    test('session within cap is allowed', () {
      final cap = RestrictedModeSessionCap();
      cap.onSessionStart(nowMs: 0);
      expect(cap.isCapExceeded(nowMs: 299000), isFalse);
    });

    test('session exceeding cap is flagged', () {
      final cap = RestrictedModeSessionCap();
      cap.onSessionStart(nowMs: 0);
      expect(cap.isCapExceeded(nowMs: 300001), isTrue);
    });

    test('exceeded cap emits SESSION_CAP_EXCEEDED', () {
      final cap = RestrictedModeSessionCap();
      cap.onSessionStart(nowMs: 0);
      cap.isCapExceeded(nowMs: 300001);
      expect(cap.errorCode, equals('SESSION_CAP_EXCEEDED'));
    });
  });
}
