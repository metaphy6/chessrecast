// §4.10 TURNS (TLS relay) failover test.
//
// Verifies that TurnsFailoverPolicy falls back to TURNS when the plain
// TURN relay is blocked (e.g. captive portal blocks UDP 3478).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/turns_policy.dart';

void main() {
  group('TurnsFailoverPolicy §4.10', () {
    test('plain TURN success → TURNS not attempted', () {
      final policy = TurnsFailoverPolicy();
      final decision = policy.onTurnResult(success: true);
      expect(decision, equals(TurnsDecision.usePlainTurn));
    });

    test('plain TURN failure → failover to TURNS', () {
      final policy = TurnsFailoverPolicy();
      final decision = policy.onTurnResult(success: false);
      expect(decision, equals(TurnsDecision.failoverToTurns));
    });

    test('TURNS port is 5349', () {
      expect(TurnsFailoverPolicy.turnsPort, equals(5349));
    });

    test('plain TURN UDP port is 3478', () {
      expect(TurnsFailoverPolicy.plainTurnPort, equals(3478));
    });
  });
}
