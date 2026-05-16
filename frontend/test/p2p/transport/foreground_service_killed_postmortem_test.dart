// §4.9 Foreground service killed postmortem test.
//
// When Android kills the foreground service, the app should:
//   - persist a "game was active" tombstone
//   - emit FOREGROUND_SERVICE_KILLED on next app launch
//   - not lose the pending move (it's in CBOR log)
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/oem_lifecycle_policy.dart';

void main() {
  group('ForegroundServiceKilledPolicy §4.9 postmortem', () {
    test('tombstone is written when foreground service is stopped', () {
      final policy = ForegroundServiceKilledPolicy();
      policy.onServiceKilled(lastSeq: 42, pendingMoveBytes: [0x01]);
      expect(policy.tombstone, isNotNull);
      expect(policy.tombstone!.lastSeq, equals(42));
    });

    test('tombstone contains pending move bytes', () {
      final policy = ForegroundServiceKilledPolicy();
      policy.onServiceKilled(lastSeq: 1, pendingMoveBytes: [0xDE, 0xAD]);
      expect(policy.tombstone!.pendingMoveBytes, equals([0xDE, 0xAD]));
    });

    test('on next launch with tombstone, error code is FOREGROUND_SERVICE_KILLED', () {
      final policy = ForegroundServiceKilledPolicy();
      policy.onServiceKilled(lastSeq: 10, pendingMoveBytes: []);
      final recovery = policy.onAppLaunch();
      expect(recovery?.errorCode, equals('FOREGROUND_SERVICE_KILLED'));
    });

    test('clean launch (no tombstone) returns null recovery', () {
      final policy = ForegroundServiceKilledPolicy();
      final recovery = policy.onAppLaunch();
      expect(recovery, isNull);
    });
  });
}
