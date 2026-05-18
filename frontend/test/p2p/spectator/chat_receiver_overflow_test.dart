// §7.10.4 chat receiver overflow proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_perf.dart';

void main() {
  group('SpectatorDecodeRateLimiter §7.10.4 receiver overflow', () {
    test('max message rate is 30 msg/s', () {
      expect(SpectatorDecodeRateLimiter.maxMsgPerSec, equals(30));
    });

    test('overflow buffer max is 100', () {
      expect(SpectatorDecodeRateLimiter.overflowBufferMax, equals(100));
    });

    test('30 messages in 1 second are accepted', () {
      final rl = SpectatorDecodeRateLimiter();
      for (var i = 0; i < SpectatorDecodeRateLimiter.maxMsgPerSec; i++) {
        expect(rl.tryDecode(0), isNull, reason: 'message \$i should be accepted');
      }
    });

    test('31st message in same second goes to overflow buffer (no error yet)', () {
      final rl = SpectatorDecodeRateLimiter();
      for (var i = 0; i < SpectatorDecodeRateLimiter.maxMsgPerSec; i++) {
        rl.tryDecode(0);
      }
      expect(rl.tryDecode(0), isNull); // buffered
    });

    test('CHAT_RECEIVER_OVERFLOW when buffer also full', () {
      final rl = SpectatorDecodeRateLimiter();
      final total = SpectatorDecodeRateLimiter.maxMsgPerSec +
          SpectatorDecodeRateLimiter.overflowBufferMax;
      for (var i = 0; i < total; i++) {
        rl.tryDecode(0);
      }
      expect(rl.tryDecode(0), equals('CHAT_RECEIVER_OVERFLOW'));
    });
  });
}
