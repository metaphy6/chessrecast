// §6.2 Telemetry KPIs — shared P2P KPI collector.
//
// Exposes all nine beta KPIs defined in §6.2 of the P2P roadmap:
//
//   1. Connection success rate (handshake completed within 30 s of intent).
//   2. Direct-connect rate vs TURN-relay rate.
//   3. P50 / P95 move RTT.
//   4. MISMATCH rate (target: 0 in 10⁵ moves).
//   5. BACKPRESSURE_DROP rate.
//   6. Push-wake redemption rate and time-to-handshake.
//   7. Recovery-flow attempts vs successes.
//   8. Battery & thermal anomalies (opt-in).
//   9. Per-mod engine KPIs (must remain at single-player baseline).
//
// All counters are in-memory only.  The optional [sink] callback is invoked
// with a snapshot whenever a KPI changes; wire it to your analytics backend
// (Firebase, Amplitude, Sentry performance, or a custom endpoint).

/// A single KPI snapshot as a plain key→value map.
typedef KpiSnapshot = Map<String, num>;

/// All nine beta telemetry KPIs for the P2P feature.
///
/// ```dart
/// final kpi = P2pKpiCollector(sink: (s) => analytics.track(s));
/// kpi.recordHandshakeAttempt(succeeded: true, elapsedMs: 1200);
/// kpi.recordMoveRtt(rttMs: 45);
/// ```
class P2pKpiCollector {
  /// Optional callback invoked (synchronously) after every mutation.
  final void Function(KpiSnapshot snapshot)? sink;

  // ── §6.2.1 Connection success rate ──────────────────────────────────────
  int _handshakeAttempts = 0;
  int _handshakeSuccesses = 0;

  // ── §6.2.2 Direct-connect vs TURN-relay rate ─────────────────────────────
  int _sessionsDirect = 0;
  int _sessionsTurn = 0;

  // ── §6.2.3 P50/P95 move RTT ──────────────────────────────────────────────
  final List<int> _rttSamples = [];

  // ── §6.2.4 MISMATCH rate ─────────────────────────────────────────────────
  int _totalMoves = 0;
  int _mismatches = 0;

  // ── §6.2.5 BACKPRESSURE_DROP rate ────────────────────────────────────────
  int _totalFrames = 0;
  int _backpressureDrops = 0;

  // ── §6.2.6 Push-wake redemption rate + time-to-handshake ─────────────────
  int _pushWakesReceived = 0;
  int _pushWakesRedeemed = 0;
  final List<int> _pushToHandshakeMs = [];

  // ── §6.2.7 Recovery-flow attempts vs successes ───────────────────────────
  int _recoveryAttempts = 0;
  int _recoverySuccesses = 0;

  // ── §6.2.8 Battery & thermal anomalies (opt-in) ──────────────────────────
  bool _batteryTelemetryOptIn = false;
  int _thermalWarnings = 0;
  int _batterySaverActivations = 0;

  // ── §6.2.9 Per-mod engine KPIs ───────────────────────────────────────────
  final Map<String, double> _modBaselineWorstMissCp = {};
  final Map<String, int> _modBatchSize = {};

  P2pKpiCollector({this.sink});

  // ── §6.2.1 ──────────────────────────────────────────────────────────────

  /// Records one connection handshake attempt.
  /// [elapsedMs] is time from user intent to ICE-connected state (or failure).
  void recordHandshakeAttempt({
    required bool succeeded,
    required int elapsedMs,
  }) {
    _handshakeAttempts++;
    if (succeeded) _handshakeSuccesses++;
    _emit();
  }

  /// Fraction of handshake attempts that succeeded.  Returns `null` when no
  /// attempts have been recorded.
  double? get connectionSuccessRate => _handshakeAttempts == 0
      ? null
      : _handshakeSuccesses / _handshakeAttempts;

  // ── §6.2.2 ──────────────────────────────────────────────────────────────

  /// Records that a session completed its ICE negotiation.
  void recordSessionType({required bool isTurnRelayed}) {
    if (isTurnRelayed) {
      _sessionsTurn++;
    } else {
      _sessionsDirect++;
    }
    _emit();
  }

  int get sessionsDirect => _sessionsDirect;
  int get sessionsTurn => _sessionsTurn;

  /// Fraction of sessions using TURN relay.
  double? get turnRelayRate {
    final total = _sessionsDirect + _sessionsTurn;
    return total == 0 ? null : _sessionsTurn / total;
  }

  // ── §6.2.3 ──────────────────────────────────────────────────────────────

  /// Records a move RTT observation in milliseconds.
  void recordMoveRtt(int rttMs) {
    _rttSamples.add(rttMs);
    _emit();
  }

  int get rttSampleCount => _rttSamples.length;

  /// Returns the p-th percentile (0–100) of recorded RTT samples, or `null`.
  int? rttPercentile(int p) {
    if (_rttSamples.isEmpty) return null;
    final sorted = List<int>.from(_rttSamples)..sort();
    final index = ((p / 100) * (sorted.length - 1)).round();
    return sorted[index];
  }

  /// P50 move RTT in ms, or `null` when no samples recorded.
  int? get rttP50 => rttPercentile(50);

  /// P95 move RTT in ms, or `null` when no samples recorded.
  int? get rttP95 => rttPercentile(95);

  // ── §6.2.4 ──────────────────────────────────────────────────────────────

  /// Records N moves, of which [mismatchCount] resulted in a MISMATCH event.
  void recordMoves({required int count, int mismatchCount = 0}) {
    _totalMoves += count;
    _mismatches += mismatchCount;
    _emit();
  }

  int get totalMoves => _totalMoves;
  int get totalMismatches => _mismatches;

  /// MISMATCH rate per move (target: 0 in 10⁵ moves → 0.00001).
  double? get mismatchRate =>
      _totalMoves == 0 ? null : _mismatches / _totalMoves;

  // ── §6.2.5 ──────────────────────────────────────────────────────────────

  /// Records N frames sent, of which [dropCount] were dropped due to back-
  /// pressure.
  void recordFrames({required int count, int dropCount = 0}) {
    _totalFrames += count;
    _backpressureDrops += dropCount;
    _emit();
  }

  int get totalFrames => _totalFrames;
  int get totalBackpressureDrops => _backpressureDrops;

  double? get backpressureDropRate =>
      _totalFrames == 0 ? null : _backpressureDrops / _totalFrames;

  // ── §6.2.6 ──────────────────────────────────────────────────────────────

  /// Records that a push-wake notification was received.
  void recordPushWakeReceived() {
    _pushWakesReceived++;
    _emit();
  }

  /// Records that a push-wake was redeemed and the full handshake completed.
  /// [timeToHandshakeMs] is time from push reception to ICE-connected state.
  void recordPushWakeRedeemed({required int timeToHandshakeMs}) {
    _pushWakesRedeemed++;
    _pushToHandshakeMs.add(timeToHandshakeMs);
    _emit();
  }

  int get pushWakesReceived => _pushWakesReceived;
  int get pushWakesRedeemed => _pushWakesRedeemed;

  double? get pushRedemptionRate => _pushWakesReceived == 0
      ? null
      : _pushWakesRedeemed / _pushWakesReceived;

  /// Median time from push reception to handshake (ms), or `null`.
  int? get medianPushToHandshakeMs {
    if (_pushToHandshakeMs.isEmpty) return null;
    final sorted = List<int>.from(_pushToHandshakeMs)..sort();
    return sorted[sorted.length ~/ 2];
  }

  // ── §6.2.7 ──────────────────────────────────────────────────────────────

  /// Records one recovery-flow attempt (ICE restart / session resume).
  void recordRecoveryAttempt({required bool succeeded}) {
    _recoveryAttempts++;
    if (succeeded) _recoverySuccesses++;
    _emit();
  }

  int get recoveryAttempts => _recoveryAttempts;
  int get recoverySuccesses => _recoverySuccesses;

  double? get recoverySuccessRate => _recoveryAttempts == 0
      ? null
      : _recoverySuccesses / _recoveryAttempts;

  // ── §6.2.8 ──────────────────────────────────────────────────────────────

  /// Enables battery & thermal anomaly collection.  Disabled by default; the
  /// user must opt in.
  void setBatteryTelemetryOptIn(bool value) {
    _batteryTelemetryOptIn = value;
    _emit();
  }

  bool get batteryTelemetryOptIn => _batteryTelemetryOptIn;

  /// Records a thermal warning event (CPU / GPU / battery temperature spike).
  /// No-op when [batteryTelemetryOptIn] is false.
  void recordThermalWarning() {
    if (!_batteryTelemetryOptIn) return;
    _thermalWarnings++;
    _emit();
  }

  /// Records a battery-saver-mode activation.
  /// No-op when [batteryTelemetryOptIn] is false.
  void recordBatterySaverActivation() {
    if (!_batteryTelemetryOptIn) return;
    _batterySaverActivations++;
    _emit();
  }

  int get thermalWarnings => _thermalWarnings;
  int get batterySaverActivations => _batterySaverActivations;

  // ── §6.2.9 ──────────────────────────────────────────────────────────────

  /// Records the worst-miss centipawn from an engine KPI batch for [mod].
  ///
  /// The value should never exceed the per-mod single-player baseline.
  void recordModKpiBatch({
    required String mod,
    required double worstMissCp,
    required int batchSize,
  }) {
    _modBaselineWorstMissCp[mod] = worstMissCp;
    _modBatchSize[mod] = batchSize;
    _emit();
  }

  /// Returns the last recorded worst-miss centipawn for [mod], or `null`.
  double? modWorstMissCp(String mod) => _modBaselineWorstMissCp[mod];

  /// Returns the set of mods that have recorded engine KPI data.
  Set<String> get modKpiMods => _modBaselineWorstMissCp.keys.toSet();

  // ── Snapshot ──────────────────────────────────────────────────────────────

  /// Returns a copy of the current KPI state as a plain key→value map.
  KpiSnapshot snapshot() {
    return {
      // §6.2.1
      'handshakeAttempts': _handshakeAttempts,
      'handshakeSuccesses': _handshakeSuccesses,
      if (connectionSuccessRate != null)
        'connectionSuccessRate': connectionSuccessRate!,

      // §6.2.2
      'sessionsDirect': _sessionsDirect,
      'sessionsTurn': _sessionsTurn,
      if (turnRelayRate != null) 'turnRelayRate': turnRelayRate!,

      // §6.2.3
      'rttSampleCount': _rttSamples.length,
      if (rttP50 != null) 'rttP50Ms': rttP50!,
      if (rttP95 != null) 'rttP95Ms': rttP95!,

      // §6.2.4
      'totalMoves': _totalMoves,
      'totalMismatches': _mismatches,
      if (mismatchRate != null) 'mismatchRate': mismatchRate!,

      // §6.2.5
      'totalFrames': _totalFrames,
      'backpressureDrops': _backpressureDrops,
      if (backpressureDropRate != null)
        'backpressureDropRate': backpressureDropRate!,

      // §6.2.6
      'pushWakesReceived': _pushWakesReceived,
      'pushWakesRedeemed': _pushWakesRedeemed,
      if (pushRedemptionRate != null) 'pushRedemptionRate': pushRedemptionRate!,
      if (medianPushToHandshakeMs != null)
        'medianPushToHandshakeMs': medianPushToHandshakeMs!,

      // §6.2.7
      'recoveryAttempts': _recoveryAttempts,
      'recoverySuccesses': _recoverySuccesses,
      if (recoverySuccessRate != null)
        'recoverySuccessRate': recoverySuccessRate!,

      // §6.2.8
      'batteryTelemetryOptIn': _batteryTelemetryOptIn ? 1 : 0,
      'thermalWarnings': _thermalWarnings,
      'batterySaverActivations': _batterySaverActivations,
    };
  }

  void _emit() => sink?.call(snapshot());
}
