// §7.9.6 auto-throttle under clock pressure proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('ChatModerationState auto-throttle clock pressure §7.9.6', () {
    test('above 30 s: no clock-pressure mute', () {
      final mod = ChatModerationState();
      mod.onClockUpdate(60000);
      expect(mod.isGloballyMuted, isFalse);
    });

    test('below 30 s: slow mode set to thirtySec automatically', () {
      final mod = ChatModerationState();
      mod.onClockUpdate(29999);
      // effectiveSlowMode is overridden to thirtySec when clock < 30 s.
      expect(mod.effectiveSlowMode.seconds, greaterThanOrEqualTo(30));
    });

    test('below 10 s: global mute applied automatically', () {
      final mod = ChatModerationState();
      mod.onClockUpdate(9999);
      expect(mod.isGloballyMuted, isTrue);
    });

    test('CHAT_AUTO_THROTTLED_CLOCK_PRESSURE code exists', () {
      expect(kChatAutoThrottledClockPressure,
          equals('CHAT_AUTO_THROTTLED_CLOCK_PRESSURE'));
    });
  });
}
