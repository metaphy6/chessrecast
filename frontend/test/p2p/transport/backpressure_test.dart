// §4.2 SCTP backpressure controller proof test.
//
// Verifies that BackpressureController detects sustained over-256 KB queues
// and surfaces BACKPRESSURE_DROP after 5 s.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/backpressure_controller.dart';

void main() {
  group('BackpressureController §4.2', () {
    test('no drop when queue is under 256 KB', () {
      final ctrl = BackpressureController();
      ctrl.onQueueUpdate(queueBytes: 200 * 1024, timestampMs: 0);
      ctrl.onQueueUpdate(queueBytes: 200 * 1024, timestampMs: 3000);
      expect(ctrl.shouldDrop, isFalse);
    });

    test('no drop when queue exceeds 256 KB but for less than 5 s', () {
      final ctrl = BackpressureController();
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 0);
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 4999);
      expect(ctrl.shouldDrop, isFalse);
    });

    test('drop when queue exceeds 256 KB sustained for 5 s', () {
      final ctrl = BackpressureController();
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 0);
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 5000);
      expect(ctrl.shouldDrop, isTrue);
    });

    test('drop reason is BACKPRESSURE_DROP', () {
      final ctrl = BackpressureController();
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 0);
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 6000);
      expect(ctrl.dropReason, equals('BACKPRESSURE_DROP'));
    });

    test('reset clears drop state after queue goes below threshold', () {
      final ctrl = BackpressureController();
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 0);
      ctrl.onQueueUpdate(queueBytes: 300 * 1024, timestampMs: 6000);
      expect(ctrl.shouldDrop, isTrue);
      ctrl.onQueueUpdate(queueBytes: 0, timestampMs: 7000);
      expect(ctrl.shouldDrop, isFalse);
    });

    test('threshold constant is 256 KB', () {
      expect(BackpressureController.thresholdBytes, equals(256 * 1024));
    });

    test('duration constant is 5 seconds', () {
      expect(BackpressureController.sustainedMs, equals(5000));
    });
  });
}
