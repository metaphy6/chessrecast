// §4.10 Metered-network TURNS prompt test.
//
// TURNS uses TCP/TLS and can consume more data than plain TURN UDP.
// When on a metered network AND TURNS is required, we show a data usage warning.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/turns_policy.dart';
import '../../../lib/services/p2p/transport/network_monitor.dart';

void main() {
  group('MeteredNetworkTurnsPrompt §4.10', () {
    test('metered + TURNS required → warn user', () {
      final policy = MeteredNetworkTurnsPolicy();
      final action = policy.evaluate(isMetered: true, turnsRequired: true);
      expect(action, equals(MeteredNetworkTurnsAction.warnUser));
    });

    test('metered + TURNS not required → no extra warning', () {
      final policy = MeteredNetworkTurnsPolicy();
      final action = policy.evaluate(isMetered: true, turnsRequired: false);
      expect(action, equals(MeteredNetworkTurnsAction.proceed));
    });

    test('unmetered + TURNS required → proceed silently', () {
      final policy = MeteredNetworkTurnsPolicy();
      final action = policy.evaluate(isMetered: false, turnsRequired: true);
      expect(action, equals(MeteredNetworkTurnsAction.proceed));
    });

    test('TURNS_HANDSHAKE_FAILED error code constant is defined', () {
      expect(TurnsErrorCodes.handshakeFailed, equals('TURNS_HANDSHAKE_FAILED'));
    });
  });
}
