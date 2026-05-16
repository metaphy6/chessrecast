// §4.7 Web capability matrix test.
//
// Ensures the WebCapabilityMatrix records support levels for
// Chromium, Firefox, and Safari for the APIs we depend on.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/web_capability_matrix.dart';

void main() {
  group('WebCapabilityMatrix §4.7', () {
    test('Chromium supports all required APIs', () {
      final caps = WebCapabilityMatrix.forBrowser(BrowserEngine.chromium);
      expect(caps.supportsDataChannel, isTrue);
      expect(caps.supportsPerfectNegotiation, isTrue);
      expect(caps.supportsTurnTls, isTrue);
    });

    test('Firefox supports required APIs (with possible caveats)', () {
      final caps = WebCapabilityMatrix.forBrowser(BrowserEngine.firefox);
      expect(caps.supportsDataChannel, isTrue);
      expect(caps.supportsTurnTls, isTrue);
    });

    test('Safari has limited support (no perfect-negotiation stable flag)', () {
      final caps = WebCapabilityMatrix.forBrowser(BrowserEngine.safari);
      // Safari supports DataChannels but perfect-negotiation support is
      // flagged as partial (requires graceful-offer fallback).
      expect(caps.supportsDataChannel, isTrue);
      expect(caps.perfectNegotiationSupportLevel,
          equals(SupportLevel.partial));
    });

    test('matrix is keyed by BrowserEngine (3 entries)', () {
      expect(BrowserEngine.values.length, equals(3));
    });
  });
}
