// §7.9.4 global mute proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('ChatModerationState global mute §7.9.4', () {
    test('global mute is false by default', () {
      expect(ChatModerationState().isGloballyMuted, isFalse);
    });

    test('setGlobalMute(muted: true) enables mute', () {
      final mod = ChatModerationState();
      mod.setGlobalMute(muted: true);
      expect(mod.isGloballyMuted, isTrue);
    });

    test('clock pressure < 10 s triggers mute', () {
      final mod = ChatModerationState();
      mod.onClockUpdate(9999);
      expect(mod.isGloballyMuted, isTrue);
    });

    test('clock pressure >= 30 s lifts clock-induced mute', () {
      final mod = ChatModerationState();
      mod.onClockUpdate(9999); // trigger mute
      mod.onClockUpdate(30001); // clock recovered
      // Host mute is separate; clock mute lifted.
      expect(mod.isGloballyMuted, isFalse);
    });

    test('CHAT_AUTO_THROTTLED_CLOCK_PRESSURE code is kChatAutoThrottledClockPressure', () {
      expect(kChatAutoThrottledClockPressure,
          equals('CHAT_AUTO_THROTTLED_CLOCK_PRESSURE'));
    });
  });
}
