import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('BYE fragment DoS — tot=200 throws ByeFragmentOutOfBoundsError (§1.8 / §8)', () {
    test('ByeFragmenter.reassemble with tot=200 throws ByeFragmentOutOfBoundsError', () {
      // Simulate a malicious peer sending fragments with tot=200
      // (well above the max of 64).
      final fakeParts = List<Map<String, dynamic>>.generate(2, (i) {
        return {
          'idx': i,
          'tot': 200, // attacker claims 200 fragments
          'data': Uint8List(100),
        };
      });
      final fakeHash = Uint8List(32);

      expect(
        () => ByeFragmenter.reassemble(fakeParts, fakeHash),
        throwsA(isA<ByeFragmentOutOfBoundsError>()),
      );
    });

    test('ByeFragmenter.reassemble with tot=64 does not throw', () {
      // 64 parts at tot=64 is exactly the limit — should not throw
      // (will throw FormatException for bad data, but NOT ByeFragmentOutOfBoundsError)
      final fakeParts = <Map<String, dynamic>>[
        {
          'idx': 0,
          'tot': 64,
          'data': Uint8List(100),
        }
      ];
      final fakeHash = Uint8List(32);

      try {
        ByeFragmenter.reassemble(fakeParts, fakeHash);
      } on ByeFragmentOutOfBoundsError {
        fail('tot=64 should not throw ByeFragmentOutOfBoundsError');
      } catch (_) {
        // FormatException (wrong hash) is expected and acceptable
      }
    });

    test('ByeFragmenter.reassemble with tot=65 throws ByeFragmentOutOfBoundsError', () {
      final fakeParts = <Map<String, dynamic>>[
        {
          'idx': 0,
          'tot': 65,
          'data': Uint8List(100),
        }
      ];
      final fakeHash = Uint8List(32);

      expect(
        () => ByeFragmenter.reassemble(fakeParts, fakeHash),
        throwsA(isA<ByeFragmentOutOfBoundsError>()),
      );
    });

    test('ByeFragmentOutOfBoundsError has meaningful toString', () {
      expect(
        const ByeFragmentOutOfBoundsError().toString(),
        contains('BYE_FRAGMENT_OUT_OF_BOUNDS'),
      );
    });

    test('fragment throws ByeFragmentOutOfBoundsError for impossibly large input', () {
      // Build a payload large enough to require > 64 fragments
      // kByeMaxFragments=64, _chunkSize=12KB → 64*12KB + 1 = 786433 bytes
      final tooLargePayload =
          Uint8List(kByeMaxFragments * 12 * 1024 + 1);
      expect(
        () => ByeFragmenter.fragment(tooLargePayload),
        throwsA(isA<ByeFragmentOutOfBoundsError>()),
      );
    });
  });
}
