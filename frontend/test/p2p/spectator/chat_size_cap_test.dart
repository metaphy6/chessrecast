// §7.9.3 chat size cap proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('ChatSizeCap §7.9.3', () {
    test('message within limits is accepted', () {
      expect(ChatSizeCap.validate('Hello!'), isNull);
    });

    test('message over 280 scalars is rejected', () {
      final msg = 'a' * (ChatSizeCap.maxScalars + 1);
      expect(ChatSizeCap.validate(msg), equals('CHAT_MESSAGE_OVERSIZED'));
    });

    test('message over 512 UTF-8 bytes is rejected', () {
      // Use 3-byte UTF-8 chars (CJK) to hit byte limit before scalar limit.
      final msg = '\u4e2d' * (ChatSizeCap.maxUtf8Bytes ~/ 3 + 1);
      expect(ChatSizeCap.validate(msg), equals('CHAT_MESSAGE_OVERSIZED'));
    });

    test('maxScalars is 280', () {
      expect(ChatSizeCap.maxScalars, equals(280));
    });

    test('maxUtf8Bytes is 512', () {
      expect(ChatSizeCap.maxUtf8Bytes, equals(512));
    });

    test('URL in message is allowed (no auto-fetch, just size-checked)', () {
      const msg = 'Check this out: https://example.com/game/123';
      expect(ChatSizeCap.validate(msg), isNull);
    });
  });
}
