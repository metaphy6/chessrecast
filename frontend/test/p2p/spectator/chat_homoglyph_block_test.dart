// §7.9.9 homoglyph block proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat_extended.dart';

void main() {
  group('ChatSanitizer homoglyph detection §7.9.9', () {
    test('message with no homoglyphs passes', () {
      final san = ChatSanitizer();
      final (_, err) = san.sanitise('normal text');
      expect(err, isNull);
    });

    test('Cyrillic а (U+0430) mixed with Latin is flagged', () {
      final san = ChatSanitizer();
      // 'p<Cyrillic а>ypal' — Latin p, Cyrillic а (U+0430), Latin ypal
      const mixed = 'p\u0430ypal';
      final (_, err) = san.sanitise(mixed);
      expect(err, equals('CHAT_HOMOGLYPH_BLOCKED'));
    });

    test('all-Latin message is NOT flagged', () {
      final san = ChatSanitizer();
      final (_, err) = san.sanitise('paypal');
      expect(err, isNull);
    });

    test('CHAT_HOMOGLYPH_BLOCKED constant is correct', () {
      expect(kChatHomoglyphBlocked, equals('CHAT_HOMOGLYPH_BLOCKED'));
    });
  });
}
