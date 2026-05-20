// T-N-007 §9.1 — Captive portal: connection state surfaces "captive portal
// detected" via HTTPS canary check.
//
// Proof: CaptivePortalDetector.evaluate() returns reachable for HTTP 204,
// suspectedPortal for other status codes, and networkError for null.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/transport/captive_portal_detector.dart';

void main() {
  const detector = CaptivePortalDetector();

  group('T-N-007 §9.1 — Captive portal detection via HTTPS canary', () {
    test('canary URL constant is the expected HTTPS endpoint', () {
      expect(detector.canaryUrl, equals(kCaptivePortalCanaryUrl));
      expect(detector.canaryUrl, startsWith('https://'),
          reason: 'canary must be HTTPS to detect portal injection');
    });

    test('expected status code is 204 No Content', () {
      expect(kCaptivePortalExpectedStatus, equals(204));
    });

    test('HTTP 204 → reachable (no captive portal)', () {
      final decision = detector.evaluate(statusCode: 204);
      expect(decision, equals(CaptivePortalDecision.reachable));
    });

    test('HTTP 200 (portal page) → suspectedPortal', () {
      final decision = detector.evaluate(statusCode: 200);
      expect(decision, equals(CaptivePortalDecision.suspectedPortal));
    });

    test('HTTP 302 (redirect to login) → suspectedPortal', () {
      final decision = detector.evaluate(statusCode: 302);
      expect(decision, equals(CaptivePortalDecision.suspectedPortal));
    });

    test('HTTP 403 → suspectedPortal', () {
      final decision = detector.evaluate(statusCode: 403);
      expect(decision, equals(CaptivePortalDecision.suspectedPortal));
    });

    test('null status (network error / timeout) → networkError', () {
      final decision = detector.evaluate(statusCode: null);
      expect(decision, equals(CaptivePortalDecision.networkError));
    });

    test('networkError and suspectedPortal are both non-reachable', () {
      expect(CaptivePortalDecision.networkError,
          isNot(equals(CaptivePortalDecision.reachable)));
      expect(CaptivePortalDecision.suspectedPortal,
          isNot(equals(CaptivePortalDecision.reachable)));
    });
  });
}
