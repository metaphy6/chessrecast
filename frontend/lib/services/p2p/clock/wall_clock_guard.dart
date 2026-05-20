/// Wall-clock guard: detects wall-clock tampering / NTP jumps.
///
/// §11.7 — A WallClockGuard is sampled alongside the monotonic clock.
/// If the wall-clock delta diverges from the monotonic elapsed by more than
/// [toleranceMs] (default 10 s), a tamper event is reported.
///
/// The guard does NOT use DateTime.now() itself — callers provide both
/// the current monotonic elapsed and the wall-clock delta so that this
/// module remains wall-clock-free.
library wall_clock_guard;

/// Result of a [WallClockGuard.sample] call.
enum WallClockSampleResult {
  ok,
  tamperDetected,
}

/// Detects wall-clock jumps by comparing a monotonic interval against
/// the observed wall-clock interval for the same period.
///
/// Stateless: each call is independent.  Callers provide both the monotonic
/// interval (`monoElapsedMs`) and the wall-clock interval (`wallDeltaMs`)
/// since the last sample; the guard simply checks that they agree within
/// [toleranceMs].
class WallClockGuard {
  /// Maximum allowed deviation (ms) between wall-clock and monotonic deltas.
  ///
  /// A deviation ≥ [toleranceMs] triggers [WallClockSampleResult.tamperDetected].
  final int toleranceMs;

  WallClockGuard({this.toleranceMs = 10000});

  /// Sample the guard.
  ///
  /// [monoElapsedMs]  — monotonic interval (ms) since the last sample.
  ///                    Pass `MonotonicClock.elapsedMs - lastSampleMonoMs`.
  /// [wallDeltaMs]    — wall-clock interval (ms) since the last sample.
  ///                    Callers compute this outside this module.
  WallClockSampleResult sample({
    required int monoElapsedMs,
    required int wallDeltaMs,
  }) {
    final deviation = (wallDeltaMs - monoElapsedMs).abs();
    if (deviation >= toleranceMs) {
      return WallClockSampleResult.tamperDetected;
    }
    return WallClockSampleResult.ok;
  }
}
