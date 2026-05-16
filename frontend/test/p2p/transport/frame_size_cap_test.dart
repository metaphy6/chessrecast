// §4.2 Per-frame size cap proof test.
//
// Verifies that FrameConstants.maxFrameSizeBytes == 16384 (16 KB) and that a
// validator rejects frames that exceed the cap.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/frame_constants.dart';

void main() {
  group('FrameConstants §4.2 size cap', () {
    test('maxFrameSizeBytes is 16 KB', () {
      expect(FrameConstants.maxFrameSizeBytes, equals(16 * 1024));
    });

    test('frame exactly at limit is accepted', () {
      final bytes = List.filled(FrameConstants.maxFrameSizeBytes, 0);
      expect(FrameConstants.validateSize(bytes.length), isTrue);
    });

    test('frame one byte over limit is rejected', () {
      expect(
          FrameConstants.validateSize(FrameConstants.maxFrameSizeBytes + 1),
          isFalse);
    });

    test('empty frame is accepted', () {
      expect(FrameConstants.validateSize(0), isTrue);
    });

    test('BYE fragmentation threshold is 12 KB (well under the 16 KB cap)', () {
      expect(FrameConstants.byeFragmentThresholdBytes,
          lessThan(FrameConstants.maxFrameSizeBytes));
      expect(FrameConstants.byeFragmentThresholdBytes, equals(12 * 1024));
    });
  });
}
