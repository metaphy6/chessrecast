// §4.8 Metered network warning test.
//
// When the user is on a metered network, the P2P layer should warn them
// before starting a WebRTC session using TURN relay (high data consumer).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/network_monitor.dart';

void main() {
  group('MeteredNetworkPolicy §4.8', () {
    test('metered network + TURN relay triggers warning', () {
      final policy = MeteredNetworkPolicy();
      final result = policy.check(
        isMetered: true,
        willUseTurnRelay: true,
      );
      expect(result, equals(MeteredNetworkAction.warnUser));
    });

    test('metered network + direct path (no TURN) → no warning', () {
      final policy = MeteredNetworkPolicy();
      final result = policy.check(
        isMetered: true,
        willUseTurnRelay: false,
      );
      expect(result, equals(MeteredNetworkAction.proceed));
    });

    test('unmetered + TURN → no warning', () {
      final policy = MeteredNetworkPolicy();
      final result = policy.check(
        isMetered: false,
        willUseTurnRelay: true,
      );
      expect(result, equals(MeteredNetworkAction.proceed));
    });

    test('warning message is user-readable', () {
      final msg = MeteredNetworkPolicy.warningMessage;
      expect(msg.isNotEmpty, isTrue);
      expect(msg.length, greaterThan(20));
    });
  });
}
