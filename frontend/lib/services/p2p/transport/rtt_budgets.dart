/// RTT/CPU/stability/efficiency budget constants.
///
/// §4.4 — These constants are the authoritative source of truth for
/// dashboard alert rules and CI performance proxy tests.
library;

class RttBudgets {
  const RttBudgets._();

  // ── Latency ──────────────────────────────────────────────────────────────

  /// P50 round-trip time for a direct (non-TURN) WebRTC connection (ms).
  static const int directP50Ms = 80;

  /// P95 round-trip time for a direct (non-TURN) WebRTC connection (ms).
  static const int directP95Ms = 200;

  /// P95 round-trip time when traffic is relayed via a TURN server (ms).
  static const int turnRelayedP95Ms = 350;

  // ── CPU/Battery ──────────────────────────────────────────────────────────

  /// Maximum average CPU usage during a 5-minute game session (%).
  static const int maxCpuPercent = 6;

  /// Sliding measurement window for CPU budget (minutes).
  static const int cpuMeasurementWindowMinutes = 5;

  /// Maximum battery consumption during a 30-minute game session (% of full
  /// charge on a 4000 mAh reference device).
  static const int batteryBudgetPercent = 4;

  // ── Stability ────────────────────────────────────────────────────────────

  /// Target move count for the long-run synthetic stability test.
  static const int longRunMoveCount = 1000;

  /// Maximum one-sided packet jitter observed during the long-run test (ms).
  static const int maxJitterMs = 500;

  /// Maximum packet-loss rate tolerated during the long-run test (%).
  static const int maxLossRatePercent = 2;

  /// Maximum resident-memory growth permitted over the long-run test (%).
  static const int maxMemoryGrowthPercent = 5;
}
