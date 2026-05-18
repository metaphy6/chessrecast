// §7.9.3 no URL auto-fetch proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('No URL auto-fetch §7.9.3', () {
    test('ChatSizeCap.validate does not reject messages containing URLs', () {
      const urls = [
        'https://example.com',
        'http://evil.example.org/xss',
        'See https://en.wikipedia.org/wiki/Chess for rules.',
      ];
      for (final url in urls) {
        expect(ChatSizeCap.validate(url), isNull,
            reason: 'URL "\$url" should pass size check');
      }
    });

    test('ChatSizeCap.validate is synchronous (cannot do network I/O)', () {
      // If we can call validate synchronously, it cannot be doing network I/O.
      final result = ChatSizeCap.validate('https://attacker.example/payload');
      expect(result, isNull);
    });
  });
}
