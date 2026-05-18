// §7.9.2 chat token bucket proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('ChatTokenBucket §7.9.2', () {
    test('burst of 3 messages is allowed', () {
      final bucket = ChatTokenBucket(nowMs: 0);
      for (var i = 0; i < ChatTokenBucket.maxTokens.round(); i++) {
        expect(bucket.consume(0), isNull, reason: 'message \$i should pass');
      }
    });

    test('4th message with no refill is rejected (CHAT_RATE_LIMITED)', () {
      final bucket = ChatTokenBucket(nowMs: 0);
      for (var i = 0; i < ChatTokenBucket.maxTokens.round(); i++) {
        bucket.consume(0);
      }
      expect(bucket.consume(0), equals('CHAT_RATE_LIMITED'));
    });

    test('refills at 1 per 3 s', () {
      final bucket = ChatTokenBucket(nowMs: 0);
      bucket.consume(0);
      bucket.consume(0);
      bucket.consume(0);
      // After 3 s, exactly 1 token should have refilled.
      expect(bucket.consume(3000), isNull);
    });

    test('maxTokens is 3', () {
      expect(ChatTokenBucket.maxTokens, equals(3.0));
    });

    test('refill rate is 1/3000 ms', () {
      expect(ChatTokenBucket.refillRatePerMs, closeTo(1.0 / 3000.0, 1e-9));
    });
  });

  group('ChatTokenBucketRegistry §7.9.2', () {
    test('registry creates per-account bucket', () {
      final reg = ChatTokenBucketRegistry();
      final result1 = reg.tryConsume('acc1', 'game1', 0);
      expect(result1, isNull);
    });

    test('registry persists bucket state across calls', () {
      final reg = ChatTokenBucketRegistry();
      for (var i = 0; i < ChatTokenBucket.maxTokens.round(); i++) {
        reg.tryConsume('acc2', 'game1', 0);
      }
      expect(reg.tryConsume('acc2', 'game1', 0), equals('CHAT_RATE_LIMITED'));
    });
  });
}
