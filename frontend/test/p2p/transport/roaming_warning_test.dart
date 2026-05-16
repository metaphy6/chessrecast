// §4.8 Roaming warning test.
//
// When the device is roaming, a user-visible warning is shown once per
// session (not every time the state changes).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/network_monitor.dart';

void main() {
  group('RoamingPolicy §4.8', () {
    test('first roaming detection emits warning', () {
      final policy = RoamingPolicy();
      expect(policy.onRoamingChanged(isRoaming: true),
          equals(RoamingAction.warnOnce));
    });

    test('second roaming detection in same session is suppressed', () {
      final policy = RoamingPolicy();
      policy.onRoamingChanged(isRoaming: true); // first
      expect(policy.onRoamingChanged(isRoaming: true),
          equals(RoamingAction.suppress));
    });

    test('turning off roaming resets the warn-once guard', () {
      final policy = RoamingPolicy();
      policy.onRoamingChanged(isRoaming: true);
      policy.onRoamingChanged(isRoaming: false); // home network
      expect(policy.onRoamingChanged(isRoaming: true),
          equals(RoamingAction.warnOnce));
    });

    test('roaming warning message is non-empty', () {
      expect(RoamingPolicy.warningMessage.isNotEmpty, isTrue);
    });
  });
}
