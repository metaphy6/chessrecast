// §7.10.7 DataChannel backpressure proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_perf.dart';

void main() {
  group('SpectatorBackpressureState §7.10.7', () {
    test('high water mark is 2000 ms', () {
      expect(SpectatorBackpressureState.highWaterMarkMs, equals(2000));
    });

    test('eviction threshold is 10000 ms', () {
      expect(SpectatorBackpressureState.evictionMs, equals(10000));
    });

    test('not above high water mark: no stall', () {
      final bp = SpectatorBackpressureState();
      expect(bp.onBackpressureTick(aboveHighWater: false, nowMs: 0), isNull);
    });

    test('above high water for >= 2 s: stall chat', () {
      final bp = SpectatorBackpressureState();
      // First tick starts the clock.
      bp.onBackpressureTick(aboveHighWater: true, nowMs: 0);
      // Tick at 2000 ms should return stall.
      final result = bp.onBackpressureTick(
          aboveHighWater: true,
          nowMs: SpectatorBackpressureState.highWaterMarkMs);
      expect(result, equals('SPECTATOR_BACKPRESSURE_STALL'));
    });

    test('above high water for >= 10 s: shed spectator', () {
      final bp = SpectatorBackpressureState();
      bp.onBackpressureTick(aboveHighWater: true, nowMs: 0);
      final result = bp.onBackpressureTick(
          aboveHighWater: true,
          nowMs: SpectatorBackpressureState.evictionMs);
      expect(result, equals('SPECTATOR_SHED_FOR_PERF'));
    });
  });
}
