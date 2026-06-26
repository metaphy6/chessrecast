// §6.5 Quality attribute targets for P2P beta → GA.
//
// Centralises the published KPI targets from docs/p2p/P2P_BETA_KPIS.md so that
// individual components can assert against a single source of truth.

/// Performance KPI targets (§6.5.1).
class P2pPerformanceKpis {
  P2pPerformanceKpis._();

  /// Connection handshake must complete within this many milliseconds.
  static const int handshakeTimeoutMs = 30000; // 30 s

  /// P95 move RTT target (milliseconds).
  static const int moveRttP95TargetMs = 300;

  /// Direct-connect rate target (fraction of sessions without TURN relay).
  static const double directConnectRateTarget = 0.60; // ≥ 60 %
}

/// Stability KPI targets (§6.5.3).
class P2pStabilityKpis {
  P2pStabilityKpis._();

  /// Minimum 7-day rolling crash-free rate for the P2P-flag-on cohort.
  static const double crashFreeRateMin = 0.999; // 99.9 %
}

/// Reliability KPI targets (§6.5.4).
class P2pReliabilityKpis {
  P2pReliabilityKpis._();

  /// MISMATCH events allowed in production over the rollout window.
  static const int maxMismatchEvents = 0;

  /// Returns `true` when [mismatchCount] violates the reliability target.
  static bool isReliabilityViolated(int mismatchCount) =>
      mismatchCount > maxMismatchEvents;
}
