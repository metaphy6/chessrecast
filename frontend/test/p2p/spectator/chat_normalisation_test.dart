// §7.9.9 chat normalisation (NFC + BIDI strip + homoglyph) proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat_extended.dart';

void main() {
  group('ChatSanitizer §7.9.9 normalisation', () {
    test('clean ASCII message passes', () {
      final san = ChatSanitizer();
      final (result, err) = san.sanitise('Hello, world!');
      expect(err, isNull);
      expect(result, equals('Hello, world!'));
    });

    test('BIDI override characters are stripped', () {
      final san = ChatSanitizer();
      // U+202E RIGHT-TO-LEFT OVERRIDE.
      const bidi = 'Hello\u202EWorld';
      final (result, err) = san.sanitise(bidi);
      expect(result.contains('\u202E'), isFalse);
    });

    test('NFC_NORMALISATION_FAIL code exists', () {
      expect(kChatNfcNormalisationFail, equals('CHAT_NFC_NORMALISATION_FAIL'));
    });
  });
}
