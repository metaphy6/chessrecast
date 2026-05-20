// T-P-HWM-001 §12.5.bullet-1 — Per-account engine-replay-version high-water-mark.
//
// Once a peer has been seen advertising engine_replay_version N, the local
// client must refuse (soft-warn) any subsequent HELLO from any peer that
// advertises a version < N.  This prevents a malicious peer from coercing an
// opponent into older (potentially-buggy) rule semantics.
//
// Distinct from the identity-key anti-rollback at
// frontend/test/p2p/identity/anti_rollback_high_water_mark_test.dart:
// that test guards key-version enrollment; THIS test guards engine-version
// downgrade detection across P2P sessions.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/engine_replay_hwm.dart';

void main() {
  group('T-P-HWM-001 §12.5 — engine replay version high-water-mark', () {
    test('initial HWM is 0 when no session has been seen', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      expect(policy.highWaterMark, equals(0));
    });

    test('first observed version sets HWM', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      policy.observeRemoteVersion(1);
      expect(policy.highWaterMark, equals(1));
    });

    test('higher version advances HWM', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      policy.observeRemoteVersion(1);
      policy.observeRemoteVersion(2);
      expect(policy.highWaterMark, equals(2));
    });

    test('same version as HWM does not advance or throw', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      policy.observeRemoteVersion(3);
      expect(() => policy.observeRemoteVersion(3), returnsNormally);
      expect(policy.highWaterMark, equals(3));
    });

    test('lower version than HWM throws EngineReplayDowngradeDetectedError', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      policy.observeRemoteVersion(5);
      expect(
        () => policy.observeRemoteVersion(4),
        throwsA(isA<EngineReplayDowngradeDetectedError>()),
      );
    });

    test('EngineReplayDowngradeDetectedError carries observed and hwm versions', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      policy.observeRemoteVersion(5);
      try {
        policy.observeRemoteVersion(3);
        fail('Expected EngineReplayDowngradeDetectedError');
      } on EngineReplayDowngradeDetectedError catch (e) {
        expect(e.observedVersion, equals(3));
        expect(e.highWaterMark, equals(5));
      }
    });

    test('HWM not advanced on downgrade attempt', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      policy.observeRemoteVersion(5);
      try {
        policy.observeRemoteVersion(2);
      } on EngineReplayDowngradeDetectedError {
        // expected
      }
      // HWM must remain 5.
      expect(policy.highWaterMark, equals(5));
    });

    test('InMemoryEngineReplayHwmStore persists HWM across policy instances', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy1 = EngineReplayHwmPolicy(store);
      policy1.observeRemoteVersion(7);

      // Same store, new policy instance (simulates reload).
      final policy2 = EngineReplayHwmPolicy(store);
      expect(policy2.highWaterMark, equals(7));
    });

    test('EngineReplayDowngradeDetectedError.toString() contains both versions', () {
      final e = EngineReplayDowngradeDetectedError(
        observedVersion: 2,
        highWaterMark: 5,
      );
      final s = e.toString();
      expect(s, contains('2'));
      expect(s, contains('5'));
    });

    test('multiple sequential advances accumulate correctly', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      for (int v = 1; v <= 10; v++) {
        policy.observeRemoteVersion(v);
      }
      expect(policy.highWaterMark, equals(10));
    });

    test('version 0 is allowed as first observed version', () {
      final store = InMemoryEngineReplayHwmStore();
      final policy = EngineReplayHwmPolicy(store);
      expect(() => policy.observeRemoteVersion(0), returnsNormally);
      expect(policy.highWaterMark, equals(0));
    });
  });
}
