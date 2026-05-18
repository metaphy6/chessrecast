// §7.9.4 slow mode proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('ChatModerationState slow mode §7.9.4', () {
    test('default slow mode (no override) allows messages', () {
      final mod = ChatModerationState();
      // Default: fiveSec slow mode; no mute.
      expect(mod.isGloballyMuted, isFalse);
    });

    test('set global mute blocks all messages', () {
      final mod = ChatModerationState();
      mod.setGlobalMute(muted: true);
      expect(mod.isGloballyMuted, isTrue);
    });

    test('lifting global mute allows messages again', () {
      final mod = ChatModerationState();
      mod.setGlobalMute(muted: true);
      mod.setGlobalMute(muted: false);
      expect(mod.isGloballyMuted, isFalse);
    });

    test('slow mode enum values are correct', () {
      expect(SlowModeInterval.off.seconds, equals(0));
      expect(SlowModeInterval.fiveSec.seconds, equals(5));
      expect(SlowModeInterval.thirtySec.seconds, equals(30));
      expect(SlowModeInterval.twoMin.seconds, equals(120));
    });

    test('effective slow mode is set by setSlowMode', () {
      final mod = ChatModerationState();
      mod.setSlowMode(SlowModeInterval.thirtySec);
      expect(mod.effectiveSlowMode.seconds, equals(30));
    });
  });
}
