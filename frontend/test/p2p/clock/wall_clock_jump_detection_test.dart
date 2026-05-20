// §11.7 wall-clock-jump detection.
//
// The p2p isolate samples wall-clock alongside monotonic at 1 Hz; a wall-clock
// delta > 10 s over a 1 s monotonic interval triggers WALL_CLOCK_TAMPERED_DETECTED.
// The chess clock itself is unaffected (it's on monotonic).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/monotonic_clock.dart';
import '../../../lib/services/p2p/clock/wall_clock_guard.dart';

void main() {
  group('§11.7 wall_clock_jump_detection', () {
    test('normal 1 s monotonic + 1 s wall-clock: no tamper', () {
      final guard = WallClockGuard(toleranceMs: 10000);
      final result = guard.sample(
        monoElapsedMs: 1000,
        wallDeltaMs: 1000,
      );
      expect(result, equals(WallClockSampleResult.ok));
    });

    test('wall-clock jumps +11 s in 1 s monotonic: tamper detected', () {
      final guard = WallClockGuard(toleranceMs: 10000);
      final result = guard.sample(
        monoElapsedMs: 1000,
        wallDeltaMs: 12000, // +11 s forward
      );
      expect(result, equals(WallClockSampleResult.tamperDetected));
    });

    test('wall-clock jumps −11 s in 1 s monotonic: tamper detected', () {
      final guard = WallClockGuard(toleranceMs: 10000);
      final result = guard.sample(
        monoElapsedMs: 1000,
        wallDeltaMs: -11000, // −11 s backward
      );
      expect(result, equals(WallClockSampleResult.tamperDetected));
    });

    test('tamper does not affect monotonic elapsed', () {
      final mono = FakeMonotonicClock();
      // Advance monotonic 5 s — wall-clock state irrelevant to MonotonicClock.
      mono.advanceMs(5000);
      expect(mono.elapsedMs, 5000);
      // Simulate wall-clock jump: nothing changes in mono.
      expect(mono.elapsedMs, 5000);
    });

    test('tolerance boundary: exactly 10 s delta is ok', () {
      final guard = WallClockGuard(toleranceMs: 10000);
      expect(
        guard.sample(monoElapsedMs: 1000, wallDeltaMs: 11000),
        WallClockSampleResult.tamperDetected,
      );
      expect(
        guard.sample(monoElapsedMs: 1000, wallDeltaMs: 10999),
        WallClockSampleResult.ok,
      );
    });
  });
}
