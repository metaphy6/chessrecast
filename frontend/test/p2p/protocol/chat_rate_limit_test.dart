import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Chat rate limiter (§1.6 / §6)', () {
    test('first 10 messages within 30s are allowed', () {
      final limiter = ChatRateLimiter();
      final now = 0;
      for (int i = 0; i < 10; i++) {
        expect(limiter.canSend(now), isTrue, reason: 'Message #${i + 1} should be allowed');
        limiter.record(now);
      }
    });

    test('11th message within 30s is denied', () {
      final limiter = ChatRateLimiter();
      const now = 0;
      for (int i = 0; i < 10; i++) {
        limiter.record(now);
      }
      expect(limiter.canSend(now), isFalse);
    });

    test('messages outside the 30s window do not count', () {
      final limiter = ChatRateLimiter();
      const firstTime = 0;

      // Send 10 messages at t=0
      for (int i = 0; i < 10; i++) {
        expect(limiter.canSend(firstTime), isTrue);
        limiter.record(firstTime);
      }

      // At t=30001ms (window expired), should be allowed again
      const laterTime = 30001;
      expect(limiter.canSend(laterTime), isTrue);
      limiter.record(laterTime);
      expect(limiter.totalSent, 11);
    });

    test('sliding window: messages at various times within window', () {
      final limiter = ChatRateLimiter();
      // Send 9 messages spread over 29s
      for (int i = 0; i < 9; i++) {
        final t = i * 3000; // 3s apart (all within 30s window)
        limiter.record(t);
      }
      // 9 messages sent; at t=29s (still within window), 10th should be allowed
      expect(limiter.canSend(29000), isTrue);
      limiter.record(29000);
      // 11th at t=29s should be denied
      expect(limiter.canSend(29000), isFalse);
    });

    test('hard ceiling: 200 messages per game', () {
      final limiter = ChatRateLimiter();
      // Simulate 200 messages with enough time between each to pass the rate limit
      for (int i = 0; i < 200; i++) {
        final t = i * 60000; // 60s apart — each in a fresh window
        expect(limiter.canSend(t), isTrue, reason: 'Message ${i + 1} should be allowed');
        limiter.record(t);
      }
      // 201st message is denied even though the window is clear
      expect(limiter.canSend(200 * 60000), isFalse);
    });

    test('canSend does not modify state', () {
      final limiter = ChatRateLimiter();
      const now = 0;
      for (int i = 0; i < 9; i++) limiter.record(now);
      // Checking canSend twice should not advance usage
      final r1 = limiter.canSend(now);
      final r2 = limiter.canSend(now);
      expect(r1, r2);
      expect(limiter.recentCount, 9);
    });

    test('totalSent and recentCount are accurate', () {
      final limiter = ChatRateLimiter();
      limiter.record(0);
      limiter.record(1000);
      limiter.record(2000);
      expect(limiter.totalSent, 3);
      expect(limiter.recentCount, 3);

      // Expire the window
      limiter.canSend(35000); // This purges old timestamps
      expect(limiter.recentCount, 0);
      expect(limiter.totalSent, 3); // totalSent never decreases
    });
  });
}
