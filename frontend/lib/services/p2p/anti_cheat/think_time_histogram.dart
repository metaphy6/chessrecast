// §13.2.b2 — move-time histogram (local-clock only).
//
// Records the per-move think times that the LOCAL peer observes on the
// wall clock.  The histogram is computed from local measurements only —
// the opponent cannot forge or suppress the data shown to the other side.
//
// This class is intentionally free of Flutter / transport dependencies so
// that it can be unit-tested in isolation.
library;

import 'dart:math' as math;

/// Accumulates per-move think-time observations (in milliseconds) and computes
/// descriptive statistics for the optional post-game histogram UI.
///
/// All `record(int ms)` calls are O(1) (amortised list append).
/// Statistics are computed lazily on the first access after a `record` call.
final class ThinkTimeHistogram {
  final List<int> _times = [];

  // Cached statistics — reset on every `record` call.
  bool _dirty = true;
  late double _mean;
  late double _stdDev;
  late int _min;
  late int _max;

  /// Records a new move time [ms] (milliseconds measured on the local clock).
  void record(int ms) {
    _times.add(ms);
    _dirty = true;
  }

  /// Clears all recorded move times and resets statistics.
  void clear() {
    _times.clear();
    _dirty = true;
  }

  /// Number of recorded moves.
  int get count => _times.length;

  /// Recorded move times in insertion order.  The list is unmodifiable so
  /// callers cannot accidentally corrupt the internal state.
  List<int> get moveTimes => List.unmodifiable(_times);

  /// Minimum observed think time in milliseconds.
  /// Returns `0` when no moves have been recorded.
  int get minMs {
    _recompute();
    return count == 0 ? 0 : _min;
  }

  /// Maximum observed think time in milliseconds.
  /// Returns `0` when no moves have been recorded.
  int get maxMs {
    _recompute();
    return count == 0 ? 0 : _max;
  }

  /// Arithmetic mean of all recorded think times in milliseconds.
  /// Returns `0.0` when no moves have been recorded.
  double get meanMs {
    _recompute();
    return count == 0 ? 0.0 : _mean;
  }

  /// Population standard deviation of recorded think times in milliseconds.
  /// Returns `0.0` when fewer than two moves have been recorded.
  double get stdDevMs {
    _recompute();
    return count <= 1 ? 0.0 : _stdDev;
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _recompute() {
    if (!_dirty || _times.isEmpty) {
      _dirty = false;
      return;
    }
    _min = _times.first;
    _max = _times.first;
    var sum = 0.0;
    for (final t in _times) {
      if (t < _min) _min = t;
      if (t > _max) _max = t;
      sum += t;
    }
    _mean = sum / _times.length;

    var variance = 0.0;
    for (final t in _times) {
      final d = t - _mean;
      variance += d * d;
    }
    _stdDev = math.sqrt(variance / _times.length);
    _dirty = false;
  }
}
