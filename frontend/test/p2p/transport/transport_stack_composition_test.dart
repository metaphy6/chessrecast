// §5.5 Transport stack composability — proof test (L5, synthetic-network).
//
// Tests that fake transports can be stacked:
//   LossyTransport(JitterTransport(FakeTransport()))
//
// and the documented presets from docs/P2P_TEST_PRESETS.md exist and produce
// valid transport stacks.
import 'dart:async';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/fake/fake_transport.dart';
import '../../../lib/services/p2p/transport/fake/jitter_transport.dart';
import '../../../lib/services/p2p/transport/fake/lossy_transport.dart';
import '../../../lib/services/p2p/transport/fake/reordering_transport.dart';
import '../../../lib/services/p2p/transport/fake/transport_presets.dart';

Future<bool> _waitFor(bool Function() cond, {int maxMs = 2000}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: maxMs));
  while (!cond()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future.delayed(const Duration(milliseconds: 5));
  }
  return true;
}

void main() {
  group('Transport stack composability §5.5', () {
    test(
      'LossyTransport(JitterTransport(FakeTransport)) delivers all frames',
      () async {
        final (innerA, innerB) = FakeTransport.pair();
        // Wrap innerA: no loss, wifiGood jitter
        final jittered = JitterTransport.wifiGood(innerA);
        final stacked = LossyTransport(jittered, lossRate: 0.0);

        int count = 0;
        innerB.incoming.listen((_) => count++);

        const n = 10;
        for (var i = 0; i < n; i++) {
          stacked.send('chess', Uint8List.fromList([i]));
        }

        final ok = await _waitFor(() => count == n, maxMs: 3000);
        expect(ok, isTrue, reason: 'Expected $n frames through stack');

        await stacked.close();
      },
    );

    test('LossyTransport(FakeTransport) with 50% loss drops ~half', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final stacked = LossyTransport(innerA, lossRate: 0.5, rng: Random(12));

      int count = 0;
      innerB.incoming.listen((_) => count++);

      const n = 500;
      for (var i = 0; i < n; i++) {
        stacked.send('chess', Uint8List.fromList([i & 0xff]));
      }

      expect(count, greaterThan(200));
      expect(count, lessThan(300));

      stacked.close();
    });

    test(
      'ReorderingTransport(LossyTransport(FakeTransport)) composes',
      () async {
        final (innerA, innerB) = FakeTransport.pair();
        final lossy = LossyTransport(innerA, lossRate: 0.0);
        final reorder = ReorderingTransport(
          lossy,
          swapProbability: 0.5,
          bufferSize: 3,
          rng: Random(7),
        );

        int count = 0;
        innerB.incoming.listen((_) => count++);

        const n = 9; // divisible by bufferSize=3 → no leftover
        for (var i = 0; i < n; i++) {
          reorder.send('clock', Uint8List.fromList([i]));
        }

        final ok = await _waitFor(() => count == n);
        expect(ok, isTrue);

        await reorder.close();
      },
    );

    test('close() on outermost closes entire stack', () async {
      final (innerA, _) = FakeTransport.pair();
      final jittered = JitterTransport.wifiGood(innerA);
      final stacked = LossyTransport(jittered, lossRate: 0.0);

      await stacked.close();
      // innerA (the base FakeTransport) should be closed
      expect(() => innerA.send('chess', Uint8List(0)), throwsStateError);
    });

    // --- Preset tests (from docs/P2P_TEST_PRESETS.md) ---

    test('preset "clean" delivers all frames with no loss/jitter', () {
      final (innerA, innerB) = FakeTransport.pair();
      final transport = TransportPresets.clean(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);

      for (var i = 0; i < 20; i++) {
        transport.send('chess', Uint8List.fromList([i]));
      }
      // clean uses FakeTransport pass-through — synchronous
      expect(count, equals(20));

      transport.close();
    });

    test('preset "wifiGood" exists and completes', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final transport = TransportPresets.wifiGood(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);
      transport.send('chess', Uint8List.fromList([1]));

      final ok = await _waitFor(() => count == 1, maxMs: 500);
      expect(ok, isTrue);

      await transport.close();
    });

    test('preset "wifiBad" exists and completes', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final transport = TransportPresets.wifiBad(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);
      transport.send('chess', Uint8List.fromList([1]));

      final ok = await _waitFor(() => count == 1, maxMs: 1500);
      expect(ok, isTrue);

      await transport.close();
    });

    test('preset "mobile4g" exists and completes', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final transport = TransportPresets.mobile4g(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);
      transport.send('chess', Uint8List.fromList([1]));

      final ok = await _waitFor(() => count == 1, maxMs: 1000);
      expect(ok, isTrue);

      await transport.close();
    });

    test('preset "mobile3g" exists and completes', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final transport = TransportPresets.mobile3g(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);
      transport.send('chess', Uint8List.fromList([1]));

      final ok = await _waitFor(() => count == 1, maxMs: 2000);
      expect(ok, isTrue);

      await transport.close();
    });

    test('preset "roaming" exists and completes', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final transport = TransportPresets.roaming(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);
      transport.send('chess', Uint8List.fromList([1]));

      final ok = await _waitFor(() => count == 1, maxMs: 2000);
      expect(ok, isTrue);

      await transport.close();
    });
  });
}
