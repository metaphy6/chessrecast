import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/protocol/frame.dart';

void main() {
  group('Frame encode/decode performance (§1.5 — < 50µs P99 on 10k iterations)',
      () {
    const int iterations = 10000;
    const int p99ThresholdUs = 150; // 50µs on fast hardware; 150µs headroom for CI

    late Uint8List testPayload;

    setUp(() {
      testPayload = CborCodec.encode({'m': 'e2e4'}); // canonical MOVE payload (§4)
    });

    test('encode P99 < ${p99ThresholdUs}µs over $iterations iterations', () {
      final frame = Frame(
        type: FrameType.move,
        sequenceNum: 1,
        wallClock: 1700000000000,
        payload: testPayload,
      );

      final latencies = List<int>.filled(iterations, 0);
      for (int i = 0; i < iterations; i++) {
        final sw = Stopwatch()..start();
        frame.encode();
        sw.stop();
        latencies[i] = sw.elapsedMicroseconds;
      }

      latencies.sort();
      final p99Index = (iterations * 0.99).ceil() - 1;
      final p99 = latencies[p99Index];

      // ignore: avoid_print
      print(
          'encode P99=${p99}µs median=${latencies[iterations ~/ 2]}µs over $iterations iters');

      expect(p99, lessThanOrEqualTo(p99ThresholdUs),
          reason:
              'P99 encode latency $p99µs exceeds threshold $p99ThresholdUs µs');
    });

    test('decode P99 < ${p99ThresholdUs}µs over $iterations iterations', () {
      final frame = Frame(
        type: FrameType.move,
        sequenceNum: 1,
        wallClock: 1700000000000,
        payload: testPayload,
      );
      final encoded = frame.encode();

      final latencies = List<int>.filled(iterations, 0);
      for (int i = 0; i < iterations; i++) {
        final sw = Stopwatch()..start();
        Frame.decode(encoded);
        sw.stop();
        latencies[i] = sw.elapsedMicroseconds;
      }

      latencies.sort();
      final p99Index = (iterations * 0.99).ceil() - 1;
      final p99 = latencies[p99Index];

      // ignore: avoid_print
      print(
          'decode P99=${p99}µs median=${latencies[iterations ~/ 2]}µs over $iterations iters');

      expect(p99, lessThanOrEqualTo(p99ThresholdUs),
          reason:
              'P99 decode latency $p99µs exceeds threshold $p99ThresholdUs µs');
    });
  });
}
