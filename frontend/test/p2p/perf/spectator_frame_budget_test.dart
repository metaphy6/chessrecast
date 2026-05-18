// §7.10.2 spectator frame budget proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_perf.dart';

void main() {
  group('SpectatorFrameBudget §7.10.2', () {
    test('budgetMs is 2.0 ms', () {
      expect(SpectatorFrameBudget.budgetMs, equals(2.0));
    });

    test('excessThresholdMs is 3000 ms', () {
      expect(SpectatorFrameBudget.excessThresholdMs, equals(3000));
    });

    test('within budget: no action', () {
      final fb = SpectatorFrameBudget();
      final result = fb.onFrameTick(workMs: 1.0, nowMs: 0);
      expect(result, isNull);
    });

    test('excess for < 3 s: no action yet', () {
      final fb = SpectatorFrameBudget();
      for (var i = 0; i < 100; i++) {
        fb.onFrameTick(workMs: 10.0, nowMs: i * 10); // 0..990 ms
      }
      // Still under 3 s threshold.
      expect(fb.onFrameTick(workMs: 10.0, nowMs: 1000), isNull);
    });

    test('excess for >= 3 s: SPECTATOR_SHED_FOR_PERF', () {
      final fb = SpectatorFrameBudget();
      fb.onFrameTick(workMs: 10.0, nowMs: 0); // start excess
      final result = fb.onFrameTick(
        workMs: 10.0,
        nowMs: SpectatorFrameBudget.excessThresholdMs,
      );
      expect(result, equals('SPECTATOR_SHED_FOR_PERF'));
    });

    test('back within budget: excess clock resets', () {
      final fb = SpectatorFrameBudget();
      fb.onFrameTick(workMs: 10.0, nowMs: 0);
      fb.onFrameTick(workMs: 1.0, nowMs: 100); // back within budget
      final result =
          fb.onFrameTick(workMs: 10.0, nowMs: SpectatorFrameBudget.excessThresholdMs);
      // Excess clock was reset; no eviction.
      expect(result, isNull);
    });
  });

  group('SpectatorLifoEvictionQueue §7.10.2', () {
    test('LIFO: last in, first out', () {
      final q = SpectatorLifoEvictionQueue();
      q.onSpectatorJoined('aaaa');
      q.onSpectatorJoined('bbbb');
      expect(q.evictOne(), equals('bbbb'));
    });

    test('count decreases on evictOne', () {
      final q = SpectatorLifoEvictionQueue();
      q.onSpectatorJoined('c1');
      q.onSpectatorJoined('c2');
      expect(q.count, equals(2));
      q.evictOne();
      expect(q.count, equals(1));
    });

    test('evictOne returns null on empty queue', () {
      expect(SpectatorLifoEvictionQueue().evictOne(), isNull);
    });

    test('onSpectatorLeft removes entry before eviction', () {
      final q = SpectatorLifoEvictionQueue();
      q.onSpectatorJoined('d1');
      q.onSpectatorJoined('d2');
      q.onSpectatorLeft('d2');
      // d2 already left; evictOne should get d1.
      expect(q.evictOne(), equals('d1'));
    });
  });
}
