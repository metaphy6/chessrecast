// §5.5 JitterTransport — proof test (L5, synthetic-network).
//
// Tests: named-factory presets exist; incoming delay is ≥ 0; delivery is
// eventually-complete; send() passes through to inner transport; close()
// propagates to inner.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/fake/fake_transport.dart';
import '../../../lib/services/p2p/transport/fake/jitter_transport.dart';

/// Pump the event loop for up to [maxMs] milliseconds, checking [condition]
/// every 5 ms.  Returns true if [condition] becomes true in time.
Future<bool> _waitFor(bool Function() condition, {int maxMs = 2000}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: maxMs));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future.delayed(const Duration(milliseconds: 5));
  }
  return true;
}

void main() {
  group('JitterTransport §5.5', () {
    test('wifiGood preset exists and delivers all frames', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final jittered = JitterTransport.wifiGood(innerA);

      final received = <Uint8List>[];
      innerB.incoming.listen((t) => received.add(t.$2));

      for (var i = 0; i < 5; i++) {
        jittered.send('chess', Uint8List.fromList([i]));
      }

      final ok = await _waitFor(() => received.length == 5, maxMs: 3000);
      expect(ok, isTrue, reason: 'Expected 5 frames via wifiGood jitter');
      expect(received.map((b) => b[0]).toList(), equals([0, 1, 2, 3, 4]));

      await jittered.close();
    });

    test('wifiBad preset exists and delivers all frames', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final jittered = JitterTransport.wifiBad(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);

      for (var i = 0; i < 3; i++) {
        jittered.send('chess', Uint8List.fromList([i]));
      }

      // wifiBad has μ=120ms; give 1500ms budget for 3 frames
      final ok = await _waitFor(() => count == 3, maxMs: 1500);
      expect(ok, isTrue, reason: 'Expected 3 frames via wifiBad jitter');

      await jittered.close();
    });

    test('mobile4g preset exists and delivers all frames', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final jittered = JitterTransport.mobile4g(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);
      jittered.send('chess', Uint8List.fromList([42]));

      final ok = await _waitFor(() => count == 1, maxMs: 1000);
      expect(ok, isTrue);

      await jittered.close();
    });

    test('mobile3g preset exists and delivers all frames', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final jittered = JitterTransport.mobile3g(innerA);

      int count = 0;
      innerB.incoming.listen((_) => count++);
      jittered.send('chess', Uint8List.fromList([99]));

      final ok = await _waitFor(() => count == 1, maxMs: 1500);
      expect(ok, isTrue);

      await jittered.close();
    });

    test('incoming frames on jittered transport are delivered', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final jitteredB = JitterTransport.wifiGood(innerB);

      final received = <(String, Uint8List)>[];
      jitteredB.incoming.listen(received.add);

      // A sends to B; B's jitter transport should deliver to jitteredB.incoming
      innerA.send('clock', Uint8List.fromList([7, 8]));

      final ok = await _waitFor(() => received.isNotEmpty, maxMs: 500);
      expect(ok, isTrue);
      expect(received.first.$1, equals('clock'));

      await jitteredB.close();
    });

    test('close() propagates to inner transport', () async {
      final (innerA, _) = FakeTransport.pair();
      final jittered = JitterTransport.wifiGood(innerA);
      await jittered.close();
      // After close, inner should be closed too
      expect(() => innerA.send('chess', Uint8List(0)), throwsStateError);
    });

    test('no frame loss after sufficient delay (zero-loss property)', () async {
      final (innerA, innerB) = FakeTransport.pair();
      final jittered = JitterTransport.wifiGood(innerA);
      const n = 20;

      int count = 0;
      innerB.incoming.listen((_) => count++);

      for (var i = 0; i < n; i++) {
        jittered.send('chess', Uint8List.fromList([i & 0xff]));
      }

      final ok = await _waitFor(() => count == n, maxMs: 5000);
      expect(ok, isTrue, reason: 'JitterTransport must not drop frames');
      expect(count, equals(n));

      await jittered.close();
    });
  });
}
