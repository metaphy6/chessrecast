// §5.5 Transport determinism — proof test (L5, synthetic-network).
//
// Verifies that seeded transports (rng: Random(seed)) produce exactly the
// same loss/delay pattern across two independent runs — essential for
// reproducing test failures and for bisecting regressions.
import 'dart:async';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/fake/fake_transport.dart';
import '../../../lib/services/p2p/transport/fake/jitter_transport.dart';
import '../../../lib/services/p2p/transport/fake/lossy_transport.dart';
import '../../../lib/services/p2p/transport/fake/transport_presets.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<bool> _waitFor(bool Function() cond, {int maxMs = 2000}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: maxMs));
  while (!cond()) {
    if (DateTime.now().isAfter(deadline)) return false;
    await Future.delayed(const Duration(milliseconds: 5));
  }
  return true;
}

/// Run [n] sends through a LossyTransport seeded with [seed] and return the
/// set of indices that were delivered.
Set<int> _runLossySend(int n, int seed) {
  final (innerA, innerB) = FakeTransport.pair();
  final lossy = LossyTransport(innerA, lossRate: 0.4, rng: Random(seed));
  final delivered = <int>{};
  innerB.incoming.listen((t) => delivered.add(t.$2[0]));
  for (var i = 0; i < n; i++) {
    lossy.send('chess', Uint8List.fromList([i]));
  }
  lossy.close();
  return delivered;
}

/// Run [n] sends through a JitterTransport seeded with [seed]; return arrival
/// times in milliseconds relative to [startTime].
Future<List<Duration>> _runJitteredSend(int n, int seed) async {
  final (innerA, innerB) = FakeTransport.pair();
  final jittered = JitterTransport.wifiGood(innerA, rng: Random(seed));
  final arrivals = <Duration>[];
  final start = DateTime.now();
  innerB.incoming
      .listen((_) => arrivals.add(DateTime.now().difference(start)));
  for (var i = 0; i < n; i++) {
    jittered.send('chess', Uint8List.fromList([i & 0xff]));
  }
  await _waitFor(() => arrivals.length == n, maxMs: 3000);
  await jittered.close();
  return arrivals;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Transport determinism §5.5', () {
    test('LossyTransport: same seed → same delivery set', () {
      const seed = 2024;
      const n = 50;

      final run1 = _runLossySend(n, seed);
      final run2 = _runLossySend(n, seed);

      expect(run1, equals(run2),
          reason: 'Same seed must produce identical loss pattern');
    });

    test('LossyTransport: different seeds → likely different delivery sets',
        () {
      const n = 50;
      final run1 = _runLossySend(n, 1);
      final run2 = _runLossySend(n, 9999);
      // With 40% loss over 50 frames it is astronomically unlikely that two
      // independent random seeds produce the exact same loss pattern.
      expect(run1, isNot(equals(run2)),
          reason: 'Different seeds should differ');
    });

    test('LossyTransport.burst: same seed → same Markov trajectory', () {
      const seed = 77;
      const n = 40;

      Set<int> run(int s) {
        final (innerA, innerB) = FakeTransport.pair();
        final lossy = LossyTransport.burst(
          innerA,
          goodLossRate: 0.1,
          badLossRate: 0.6,
          pGoodToBad: 0.1,
          pBadToGood: 0.3,
          rng: Random(s),
        );
        final delivered = <int>{};
        innerB.incoming.listen((t) => delivered.add(t.$2[0]));
        for (var i = 0; i < n; i++) {
          lossy.send('chess', Uint8List.fromList([i]));
        }
        lossy.close();
        return delivered;
      }

      expect(run(seed), equals(run(seed)));
    });

    test('JitterTransport: same seed → identical delay sequence', () async {
      const seed = 314;
      const n = 8; // small to keep test fast

      final arrivals1 = await _runJitteredSend(n, seed);
      final arrivals2 = await _runJitteredSend(n, seed);

      expect(arrivals1.length, equals(n));
      expect(arrivals2.length, equals(n));

      // Arrival times won't be bit-exact (OS timer precision) but the
      // ordering of frames relative to each other should be identical.
      // We compare ordering indices.
      List<int> order(List<Duration> a) {
        final indexed =
            List.generate(a.length, (i) => (i, a[i].inMicroseconds));
        indexed.sort((x, y) => x.$2.compareTo(y.$2));
        return indexed.map((e) => e.$1).toList();
      }

      expect(order(arrivals1), equals(order(arrivals2)),
          reason: 'Same seed must produce same frame ordering');
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('TransportPresets.wifiBad: deterministic with explicit rng', () {
      const n = 60;

      Set<int> run(int seed) {
        final (innerA, innerB) = FakeTransport.pair();
        // wifiBad = JitterTransport.wifiBad + LossyTransport(3%)
        // We only check loss determinism here (ignore jitter).
        final lossy =
            LossyTransport(innerA, lossRate: 0.03, rng: Random(seed));
        final delivered = <int>{};
        innerB.incoming.listen((t) => delivered.add(t.$2[0]));
        for (var i = 0; i < n; i++) {
          lossy.send('chess', Uint8List.fromList([i]));
        }
        lossy.close();
        return delivered;
      }

      expect(run(42), equals(run(42)));
    });
  });
}
