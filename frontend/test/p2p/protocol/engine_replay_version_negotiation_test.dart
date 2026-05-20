// T-P-ERV-001 §12.2 — engine_replay_version negotiation in HELLO/HELLO_ACK.
//
// Proof: matching versions succeed; mismatches throw EngineVersionMismatchError
// carrying both local and remote versions; kEngineReplayVersion == 1.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/engine_replay_version.dart';

void main() {
  group('T-P-ERV-001 §12.2 — engine_replay_version negotiation', () {
    test('kEngineReplayVersion is 1', () {
      expect(kEngineReplayVersion, equals(1));
    });

    test('matching versions pass without error', () {
      expect(
        () => validateHelloEngineReplayVersion(
          localVersion: kEngineReplayVersion,
          remoteVersion: kEngineReplayVersion,
        ),
        returnsNormally,
      );
    });

    test(
      'remote version higher than local throws EngineVersionMismatchError',
      () {
        expect(
          () => validateHelloEngineReplayVersion(
            localVersion: 1,
            remoteVersion: 2,
          ),
          throwsA(isA<EngineVersionMismatchError>()),
        );
      },
    );

    test(
      'remote version lower than local throws EngineVersionMismatchError',
      () {
        expect(
          () => validateHelloEngineReplayVersion(
            localVersion: 2,
            remoteVersion: 1,
          ),
          throwsA(isA<EngineVersionMismatchError>()),
        );
      },
    );

    test('EngineVersionMismatchError carries local and remote versions', () {
      try {
        validateHelloEngineReplayVersion(localVersion: 3, remoteVersion: 1);
        fail('Expected EngineVersionMismatchError');
      } on EngineVersionMismatchError catch (e) {
        expect(e.localVersion, equals(3));
        expect(e.remoteVersion, equals(1));
      }
    });

    test('EngineVersionMismatchError.toString() contains both versions', () {
      final e = EngineVersionMismatchError(localVersion: 3, remoteVersion: 1);
      final s = e.toString();
      expect(s, contains('3'));
      expect(s, contains('1'));
    });

    test('addEngineVersionToHello injects engine_replay_version field', () {
      final payload = <String, dynamic>{
        'pub': [1, 2, 3],
        'mod': 1,
      };
      final updated = addEngineVersionToHello(payload, kEngineReplayVersion);
      expect(updated['engine_replay_version'], equals(kEngineReplayVersion));
      // Original fields preserved.
      expect(updated['pub'], equals([1, 2, 3]));
      expect(updated['mod'], equals(1));
    });

    test('extractEngineVersionFromHello reads engine_replay_version field', () {
      final payload = <String, dynamic>{
        'pub': [1, 2, 3],
        'engine_replay_version': 1,
      };
      expect(extractEngineVersionFromHello(payload), equals(1));
    });

    test('extractEngineVersionFromHello missing field returns null', () {
      final payload = <String, dynamic>{
        'pub': [1, 2, 3],
      };
      expect(extractEngineVersionFromHello(payload), isNull);
    });

    test('version field is a u32 (non-negative int ≤ 2^32-1)', () {
      // kEngineReplayVersion must fit in a u32 for the 4-byte wire efficiency.
      expect(kEngineReplayVersion, greaterThanOrEqualTo(0));
      expect(kEngineReplayVersion, lessThanOrEqualTo(0xFFFFFFFF));
    });
  });
}
