// §7.9.8 tournament chat default mute proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_chat.dart';

void main() {
  group('GameChatPolicy tournament lockdown §7.9.8', () {
    test('tournament game blocks chat by default', () {
      const policy = GameChatPolicy(
        isTournament: true,
        isRated: false,
        hostOptedIn: false,
      );
      expect(policy.validatePolicy(), equals('CHAT_TOURNAMENT_LOCKED'));
    });

    test('rated game blocks chat by default', () {
      const policy = GameChatPolicy(
        isTournament: false,
        isRated: true,
        hostOptedIn: false,
      );
      expect(policy.validatePolicy(), equals('CHAT_TOURNAMENT_LOCKED'));
    });

    test('casual game allows chat by default', () {
      const policy = GameChatPolicy(
        isTournament: false,
        isRated: false,
        hostOptedIn: false,
      );
      expect(policy.validatePolicy(), isNull);
    });

    test('tournament game with host opt-in allows chat', () {
      const policy = GameChatPolicy(
        isTournament: true,
        isRated: false,
        hostOptedIn: true,
      );
      expect(policy.validatePolicy(), isNull);
    });

    test('CHAT_TOURNAMENT_LOCKED constant exists', () {
      expect(kChatTournamentLocked, equals('CHAT_TOURNAMENT_LOCKED'));
    });
  });
}
