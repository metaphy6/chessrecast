// §7.9.2 chat bucket persists across rejoin proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('ChatTokenBucketRegistry persists across rejoin §7.9.2', () {
    test('after 2 messages, bucket still drained after disconnect and rejoin', () {
      final reg = ChatTokenBucketRegistry();
      const account = 'rejoiner';

      reg.tryConsume(account, 'game1', 0);
      reg.tryConsume(account, 'game1', 0);

      // Third message still passes (1 token left).
      expect(reg.tryConsume(account, 'game1', 0), isNull);

      // Fourth message fails — bucket was not reset by disconnect.
      expect(reg.tryConsume(account, 'game1', 0), equals('CHAT_RATE_LIMITED'),
          reason: 'bucket must persist across rejoin; reset would allow burst abuse');
    });

    test('different accounts have independent buckets', () {
      final reg = ChatTokenBucketRegistry();
      for (var i = 0; i < ChatTokenBucket.maxTokens.round(); i++) {
        reg.tryConsume('acc_a', 'game1', 0);
      }
      expect(reg.tryConsume('acc_b', 'game1', 0), isNull);
    });
  });
}
