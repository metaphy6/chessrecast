// §4.4 Reliability — network chaos policy test.
//
// Verifies that NetworkHealPolicy defines the correct recovery window and
// that the NETWORK_LOST error code is emitted after the window expires.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/network_heal_policy.dart';

void main() {
  group('NetworkHealPolicy §4.4 reliability', () {
    test('heal window is 10 seconds', () {
      expect(NetworkHealPolicy.healWindowMs, equals(10000));
    });

    test('heal result is healed when recovery happens within 10 s', () {
      final policy = NetworkHealPolicy();
      policy.onDisconnect(timestampMs: 0);
      policy.onReconnect(timestampMs: 9999);
      expect(policy.result, equals(HealResult.healed));
    });

    test('heal result is networkLost when no recovery within 10 s', () {
      final policy = NetworkHealPolicy();
      policy.onDisconnect(timestampMs: 0);
      policy.onTimeout(timestampMs: 10001);
      expect(policy.result, equals(HealResult.networkLost));
    });

    test('networkLost error code is "NETWORK_LOST"', () {
      final policy = NetworkHealPolicy();
      policy.onDisconnect(timestampMs: 0);
      policy.onTimeout(timestampMs: 10001);
      expect(policy.errorCode, equals('NETWORK_LOST'));
    });

    test('network change types include airplane/wifi/cellular/vpn', () {
      expect(NetworkChangeType.values, containsAll([
        NetworkChangeType.airplaneToggle,
        NetworkChangeType.wifiReconnect,
        NetworkChangeType.cellularHandoff,
        NetworkChangeType.vpnToggle,
      ]));
    });
  });
}
