/// NTP offset/delay estimator for P2P clock synchronisation.
///
/// §11.2 — RFC 5905 timestamp equations:
///   offset = ((T2 - T1) + (T3 - T4)) / 2
///   delay  = (T4 - T1) - (T3 - T2)
///
/// Where (all in ms since any shared epoch):
///   T1 = time client sent the request
///   T2 = time server received the request
///   T3 = time server sent the response
///   T4 = time client received the response
///
/// EWMA smoothing (α = 0.125 per RFC 5905) with best-RTT selection.
///
/// §11.2 desync budget:
///   • delay_p95 > 1 s  → [DesyncBudgetResult.clockDesyncBeyondBudget]
///   • |offset| > 500 ms → [DesyncBudgetResult.clockDesyncBeyondBudget]
library ntp_estimator;

/// A single NTP estimate (offset and one-way delay, both in ms).
class NtpEstimate {
  final int offsetMs;
  final int delayMs;

  const NtpEstimate({required this.offsetMs, required this.delayMs});

  static const zero = NtpEstimate(offsetMs: 0, delayMs: 0);
}

/// Result of the desync-budget evaluation.
enum DesyncBudgetResult {
  withinBudget,
  clockDesyncBeyondBudget,
}

/// Rolling NTP estimator that maintains a sliding window of the last 30
/// samples (≈150 s at 5 s intervals) and exposes:
///   • [estimate] — EWMA-smoothed current estimate.
///   • [best]     — sample with the lowest round-trip delay (most accurate).
///   • [evaluateBudget] — whether the current estimate exceeds budget.
class NtpEstimator {
  static const int _windowSize = 30;
  static const double _alpha = 0.125;

  final List<NtpEstimate> _samples = [];
  NtpEstimate _ewma = NtpEstimate.zero;

  bool _initialized = false;

  /// Record a single four-timestamp NTP exchange.
  ///
  /// [tSendMs]     T1 — when we sent the request.
  /// [tRecvMs]     T2 — when the peer received it.
  /// [tRespMs]     T3 — when the peer sent the reply.
  /// [tRespEchoMs] T4 — when we received the reply.
  void recordSample({
    required int tSendMs,
    required int tRecvMs,
    required int tRespMs,
    required int tRespEchoMs,
  }) {
    final offset = ((tRecvMs - tSendMs) + (tRespMs - tRespEchoMs)) ~/ 2;
    final delay = (tRespEchoMs - tSendMs) - (tRespMs - tRecvMs);
    final sample = NtpEstimate(
      offsetMs: offset,
      delayMs: delay.clamp(0, 1 << 30),
    );

    if (_samples.length >= _windowSize) {
      _samples.removeAt(0);
    }
    _samples.add(sample);

    // Initialize EWMA from first sample (RFC 5905 §11 fast start).
    if (!_initialized) {
      _ewma = sample;
      _initialized = true;
    } else {
      // EWMA update.
      _ewma = NtpEstimate(
        offsetMs:
            (_alpha * sample.offsetMs + (1 - _alpha) * _ewma.offsetMs).round(),
        delayMs:
            (_alpha * sample.delayMs + (1 - _alpha) * _ewma.delayMs).round(),
      );
    }
  }

  /// EWMA-smoothed current estimate.
  NtpEstimate get estimate => _ewma;

  /// The sample with the lowest measured round-trip delay.
  ///
  /// Samples with lower delay have less path asymmetry and thus the most
  /// accurate offset measurement.
  NtpEstimate get best {
    if (_samples.isEmpty) return NtpEstimate.zero;
    return _samples.reduce(
        (a, b) => a.delayMs <= b.delayMs ? a : b);
  }

  /// Evaluate whether the current network conditions exceed the desync budget.
  ///
  /// Budget exceeded when:
  ///   • p95(delay) > 1000 ms, OR
  ///   • |ewma.offsetMs| > 500 ms
  DesyncBudgetResult evaluateBudget() {
    if (_samples.isEmpty) return DesyncBudgetResult.withinBudget;

    // Compute p95 delay.
    final sortedDelays = _samples.map((s) => s.delayMs).toList()..sort();
    final p95Index = (sortedDelays.length * 0.95).ceil() - 1;
    final p95Delay = sortedDelays[p95Index.clamp(0, sortedDelays.length - 1)];

    if (p95Delay > 1000) return DesyncBudgetResult.clockDesyncBeyondBudget;
    if (_ewma.offsetMs.abs() > 500) {
      return DesyncBudgetResult.clockDesyncBeyondBudget;
    }
    return DesyncBudgetResult.withinBudget;
  }

  /// Number of samples in the current window.
  int get sampleCount => _samples.length;
}
