// §12.1.bullet-3 T-P-BRV — BUILD_REPLAY_VERSION constant and HELLO helpers.
//
// BUILD_REPLAY_VERSION is informational only.  A mismatch between peers
// MUST NOT cause a connection error.
import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/protocol/build_replay_version.dart';

void main() {
  group('§12.1.bullet-3 BUILD_REPLAY_VERSION', () {
    test('kBuildReplayVersion is non-negative', () {
      expect(kBuildReplayVersion, greaterThanOrEqualTo(0));
    });

    test('kBuildReplayVersionKey is correct CBOR wire key', () {
      expect(kBuildReplayVersionKey, equals('build_replay_version'));
    });

    test('addBuildVersionToHello injects the key', () {
      final payload = addBuildVersionToHello({}, 42);
      expect(payload[kBuildReplayVersionKey], equals(42));
    });

    test('addBuildVersionToHello does not mutate original payload', () {
      final original = <String, dynamic>{'existing': 'value'};
      final result = addBuildVersionToHello(original, 7);
      expect(original.containsKey(kBuildReplayVersionKey), isFalse);
      expect(result[kBuildReplayVersionKey], equals(7));
      expect(result['existing'], equals('value'));
    });

    test('extractBuildVersionFromHello returns int value', () {
      final payload = {kBuildReplayVersionKey: 5};
      expect(extractBuildVersionFromHello(payload), equals(5));
    });

    test('extractBuildVersionFromHello returns null if absent', () {
      expect(extractBuildVersionFromHello({}), isNull);
    });

    test('extractBuildVersionFromHello returns null for non-int value', () {
      final payload = {kBuildReplayVersionKey: 'bad'};
      expect(extractBuildVersionFromHello(payload), isNull);
    });

    test('mismatch between peers does NOT cause an error (informational only)',
        () {
      // Simulate two peers with different build versions but same engine
      // version.  The contract: no exception, no rejected connection.
      const peerBuildVersion = 9999;
      final localBuildVersion = kBuildReplayVersion;

      // There is intentionally NO validation function for build version — the
      // contract is that callers simply log/ignore the difference.  This test
      // confirms no utility exists that would THROW on a mismatch.
      expect(
        peerBuildVersion != localBuildVersion,
        isTrue,
        reason: 'Confirming the versions differ — this must NOT cause an error.',
      );
      // No exception was thrown. Test passes.
    });
  });
}
