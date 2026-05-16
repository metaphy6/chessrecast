// §4.10 TURNS auto-promote test.
//
// Verifies that TURNS (TLS) is automatically included in the ICE
// candidate list when the connectivity probe determines it is needed.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/turns_policy.dart';

void main() {
  group('TurnsAutoPromote §4.10', () {
    test('TURNS url is included when TURN UDP is blocked', () {
      final candidates = TurnsAutoPromote.buildIceCandidateUrls(
        turnUdpBlocked: true,
      );
      final hasturns = candidates.any((u) => u.startsWith('turns:'));
      expect(hasturns, isTrue);
    });

    test('TURNS url is NOT added when TURN UDP is accessible', () {
      final candidates = TurnsAutoPromote.buildIceCandidateUrls(
        turnUdpBlocked: false,
      );
      final hasTurns = candidates.any((u) => u.startsWith('turns:'));
      expect(hasTurns, isFalse);
    });

    test('TURNS url uses the correct host and port', () {
      final candidates = TurnsAutoPromote.buildIceCandidateUrls(
        turnUdpBlocked: true,
      );
      final turnsUrl = candidates.firstWhere((u) => u.startsWith('turns:'));
      expect(turnsUrl, contains('turn.chessrecast.app'));
      expect(turnsUrl, contains('5349'));
    });
  });
}
