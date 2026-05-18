// §7.10.2 LIFO eviction shed proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_perf.dart';

void main() {
  group('SpectatorLifoEvictionQueue §7.10.2 LIFO shed', () {
    test('LIFO: last added is first evicted', () {
      final q = SpectatorLifoEvictionQueue();
      q.onSpectatorJoined('aaaa');
      q.onSpectatorJoined('bbbb');
      expect(q.evictOne(), equals('bbbb'));
    });

    test('after eviction, previously second-to-last becomes next candidate', () {
      final q = SpectatorLifoEvictionQueue();
      q.onSpectatorJoined('0001');
      q.onSpectatorJoined('0002');
      q.onSpectatorJoined('0003');
      q.evictOne(); // removes 0003
      expect(q.evictOne(), equals('0002'));
    });

    test('count decreases after eviction', () {
      final q = SpectatorLifoEvictionQueue();
      q.onSpectatorJoined('x1');
      q.onSpectatorJoined('x2');
      expect(q.count, equals(2));
      q.evictOne();
      expect(q.count, equals(1));
    });

    test('SPECTATOR_SHED_FOR_PERF constant exists', () {
      expect(kSpectatorShedForPerf, equals('SPECTATOR_SHED_FOR_PERF'));
    });

    test('evictOne returns null on empty queue', () {
      expect(SpectatorLifoEvictionQueue().evictOne(), isNull);
    });
  });
}
