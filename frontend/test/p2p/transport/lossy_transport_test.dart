// §5.5 LossyTransport — proof test (L5, synthetic-network).
//
// Tests: uniform loss rate; per-channel loss rates; Gilbert-Elliot burst
// model; zero-loss rate passes all frames; send() passes through; close()
// propagates.
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/fake/fake_transport.dart';
import '../../../lib/services/p2p/transport/fake/lossy_transport.dart';

void main() {
  group('LossyTransport §5.5', () {
    test('lossRate=0.0 drops no frames (100 frames all delivered)', () {
      final (innerA, innerB) = FakeTransport.pair();
      final lossy = LossyTransport(innerA, lossRate: 0.0);

      int count = 0;
      innerB.incoming.listen((_) => count++);

      for (var i = 0; i < 100; i++) {
        lossy.send('chess', Uint8List.fromList([i & 0xff]));
      }
      expect(count, equals(100));

      lossy.close();
    });

    test('lossRate=1.0 drops all frames', () {
      final (innerA, innerB) = FakeTransport.pair();
      final lossy = LossyTransport(innerA, lossRate: 1.0);

      int count = 0;
      innerB.incoming.listen((_) => count++);

      for (var i = 0; i < 50; i++) {
        lossy.send('chess', Uint8List.fromList([i & 0xff]));
      }
      expect(count, equals(0));

      lossy.close();
    });

    test('lossRate=0.5 drops roughly half (within 20% for 1000 frames)', () {
      final (innerA, innerB) = FakeTransport.pair();
      final lossy =
          LossyTransport(innerA, lossRate: 0.5, rng: Random(42));

      int count = 0;
      innerB.incoming.listen((_) => count++);

      const n = 1000;
      for (var i = 0; i < n; i++) {
        lossy.send('chess', Uint8List.fromList([i & 0xff]));
      }
      // Expect between 400 and 600 delivered (50% ± 10%)
      expect(count, greaterThan(400));
      expect(count, lessThan(600));

      lossy.close();
    });

    test('per-channel loss: chess lossy, clock lossless', () {
      final (innerA, innerB) = FakeTransport.pair();
      final lossy = LossyTransport(
        innerA,
        channelLossRates: {'chess': 1.0, 'clock': 0.0},
        rng: Random(7),
      );

      int chessCount = 0;
      int clockCount = 0;
      innerB.incoming.listen((t) {
        if (t.$1 == 'chess') chessCount++;
        if (t.$1 == 'clock') clockCount++;
      });

      for (var i = 0; i < 20; i++) {
        lossy.send('chess', Uint8List.fromList([i]));
        lossy.send('clock', Uint8List.fromList([i]));
      }
      expect(chessCount, equals(0));
      expect(clockCount, equals(20));

      lossy.close();
    });

    test('Gilbert-Elliot burst: delivers frames in good state', () {
      final (innerA, innerB) = FakeTransport.pair();
      // Good state with no transitions and zero loss — all frames pass
      final lossy = LossyTransport.burst(
        innerA,
        goodLossRate: 0.0,
        badLossRate: 0.0,
        pGoodToBad: 0.0,
        pBadToGood: 1.0, // stuck in good state
        rng: Random(1),
      );

      int count = 0;
      innerB.incoming.listen((_) => count++);

      for (var i = 0; i < 30; i++) {
        lossy.send('chess', Uint8List.fromList([i]));
      }
      expect(count, equals(30));

      lossy.close();
    });

    test('Gilbert-Elliot burst: drops all frames in bad state', () {
      final (innerA, innerB) = FakeTransport.pair();
      // Bad state, stuck there, 100% loss
      final lossy = LossyTransport.burst(
        innerA,
        goodLossRate: 0.0,
        badLossRate: 1.0,
        pGoodToBad: 1.0, // immediately transitions to bad
        pBadToGood: 0.0, // stuck in bad state
        rng: Random(2),
        startInBadState: true,
      );

      int count = 0;
      innerB.incoming.listen((_) => count++);

      for (var i = 0; i < 30; i++) {
        lossy.send('chess', Uint8List.fromList([i]));
      }
      expect(count, equals(0));

      lossy.close();
    });

    test('incoming frames are filtered by loss rate', () {
      final (innerA, innerB) = FakeTransport.pair();
      final lossyB =
          LossyTransport(innerB, lossRate: 1.0); // drop all incoming

      final received = <Uint8List>[];
      lossyB.incoming.listen((t) => received.add(t.$2));

      innerA.send('chess', Uint8List.fromList([1]));
      innerA.send('chess', Uint8List.fromList([2]));

      expect(received, isEmpty); // all dropped by lossy filter

      lossyB.close();
    });

    test('close() propagates to inner transport', () {
      final (innerA, _) = FakeTransport.pair();
      final lossy = LossyTransport(innerA, lossRate: 0.0);
      lossy.close();
      expect(() => innerA.send('chess', Uint8List(0)), throwsStateError);
    });
  });
}
