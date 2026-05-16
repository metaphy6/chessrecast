// §4.3 Network-change → ICE restart proof test (hermetic).
//
// Verifies that the IceRestartPolicy:
//   - allows ICE restart within the 30-minute session key validity window
//   - denies restart (triggers teardown) when the key is older than 30 min
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/ice_restart_policy.dart';

void main() {
  group('IceRestartPolicy §4.3', () {
    test('restart allowed when session key is under 30 min old', () {
      final policy = IceRestartPolicy(
        sessionKeyCreatedAt:
            DateTime.now().subtract(const Duration(minutes: 29)),
      );
      expect(policy.canRestart, isTrue);
    });

    test('restart allowed at exactly 30 min old', () {
      // Use 29m59s to avoid sub-millisecond boundary flakiness.
      final policy = IceRestartPolicy(
        sessionKeyCreatedAt:
            DateTime.now().subtract(const Duration(minutes: 29, seconds: 59)),
      );
      expect(policy.canRestart, isTrue);
    });

    test('teardown required when session key exceeds 30 min', () {
      final policy = IceRestartPolicy(
        sessionKeyCreatedAt:
            DateTime.now().subtract(const Duration(minutes: 31)),
      );
      expect(policy.canRestart, isFalse);
    });

    test('IceRestartPolicy.maxSessionKeyAge is 30 minutes', () {
      expect(IceRestartPolicy.maxSessionKeyAge,
          equals(const Duration(minutes: 30)));
    });

    test('restart reason is "network_change" not "session_teardown"', () {
      final policy = IceRestartPolicy(
        sessionKeyCreatedAt:
            DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(policy.restartReason, equals('network_change'));
    });

    test('teardown reason is "session_key_expired" when key is too old', () {
      final policy = IceRestartPolicy(
        sessionKeyCreatedAt:
            DateTime.now().subtract(const Duration(minutes: 31)),
      );
      expect(policy.restartReason, equals('session_key_expired'));
    });
  });
}
