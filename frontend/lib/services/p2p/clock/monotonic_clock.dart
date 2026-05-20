/// Monotonic clock abstraction for the chess clock module.
///
/// All time measurements in the chess clock use this interface so that:
///   • Production code uses [StopwatchMonotonicClock] (Dart Stopwatch is
///     monotonic by specification on all Flutter platforms).
///   • Tests use [FakeMonotonicClock] with [FakeMonotonicClock.advanceMs] to
///     control time deterministically.
///   • A test that probes the "no monotonic clock" failure path uses
///     [UnavailableMonotonicClock].
///
/// §11.7 mandate: no `DateTime.now()` / `DateTime.timestamp()` inside
/// `lib/services/p2p/clock/`.  All callers in this directory must obtain
/// elapsed time exclusively through this interface.
library monotonic_clock;

/// Abstract monotonic clock interface.
abstract class MonotonicClock {
  /// Elapsed milliseconds since the clock was started.
  ///
  /// Guaranteed to be non-decreasing regardless of host wall-clock changes.
  int get elapsedMs;

  /// Whether a monotonic clock is available on this platform.
  bool get isAvailable;
}

/// Production implementation backed by Dart's [Stopwatch].
///
/// Dart's `Stopwatch` always uses the most precise monotonic timer available
/// on the platform (CLOCK_MONOTONIC on Linux/Android, mach_absolute_time on
/// iOS/macOS, QueryPerformanceCounter on Windows).
class StopwatchMonotonicClock implements MonotonicClock {
  final Stopwatch _sw = Stopwatch()..start();

  @override
  int get elapsedMs => _sw.elapsedMilliseconds;

  @override
  bool get isAvailable => true;
}

/// Fake monotonic clock for deterministic testing.
///
/// Time stands still until [advanceMs] is called explicitly, making chess
/// clock tests reproducible and fast.
class FakeMonotonicClock implements MonotonicClock {
  int _elapsedMs = 0;

  /// Advance the fake clock by [ms] milliseconds.
  void advanceMs(int ms) {
    if (ms < 0) throw ArgumentError.value(ms, 'ms', 'Must be non-negative');
    _elapsedMs += ms;
  }

  @override
  int get elapsedMs => _elapsedMs;

  @override
  bool get isAvailable => true;
}

/// Monotonic clock stub that always throws [MonotonicClockUnavailableError].
///
/// Used in tests that verify the "timed session refused" path when no
/// monotonic clock is available on the platform.
class UnavailableMonotonicClock implements MonotonicClock {
  @override
  int get elapsedMs => throw MonotonicClockUnavailableError();

  @override
  bool get isAvailable => false;
}

/// Thrown when a timed chess session is attempted but no monotonic clock
/// is available on the current platform.
class MonotonicClockUnavailableError extends Error {
  @override
  String toString() =>
      'MonotonicClockUnavailableError: Timed sessions require a monotonic '
      'clock, which is not available on this platform.';
}
