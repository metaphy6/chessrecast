// §6.2 Telemetry KPI collector proof tests.
//
// Covers all nine beta KPI groups:
//   6.2.1  Connection success rate
//   6.2.2  Direct-connect vs TURN-relay rate
//   6.2.3  P50/P95 move RTT
//   6.2.4  MISMATCH rate
//   6.2.5  BACKPRESSURE_DROP rate
//   6.2.6  Push-wake redemption rate + time-to-handshake
//   6.2.7  Recovery-flow attempts vs successes
//   6.2.8  Battery & thermal anomalies (opt-in gate)
//   6.2.9  Per-mod engine KPIs
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/telemetry/p2p_kpi_collector.dart';

void main() {
  late P2pKpiCollector kpi;

  setUp(() => kpi = P2pKpiCollector());

  // ── §6.2.1 Connection success rate ──────────────────────────────────────
  group('6.2.1 connection success rate', () {
    test('starts at null (no attempts)', () {
      expect(kpi.connectionSuccessRate, isNull);
    });

    test('all successes → rate 1.0', () {
      kpi.recordHandshakeAttempt(succeeded: true, elapsedMs: 1200);
      kpi.recordHandshakeAttempt(succeeded: true, elapsedMs: 1500);
      expect(kpi.connectionSuccessRate, equals(1.0));
    });

    test('one failure in three attempts → rate 2/3', () {
      kpi.recordHandshakeAttempt(succeeded: true, elapsedMs: 800);
      kpi.recordHandshakeAttempt(succeeded: true, elapsedMs: 900);
      kpi.recordHandshakeAttempt(succeeded: false, elapsedMs: 31000);
      expect(kpi.connectionSuccessRate, closeTo(2 / 3, 1e-9));
    });
  });

  // ── §6.2.2 Direct-connect vs TURN-relay rate ─────────────────────────────
  group('6.2.2 direct vs TURN rate', () {
    test('starts at null (no sessions)', () {
      expect(kpi.turnRelayRate, isNull);
    });

    test('all direct → TURN rate 0.0', () {
      kpi.recordSessionType(isTurnRelayed: false);
      kpi.recordSessionType(isTurnRelayed: false);
      expect(kpi.turnRelayRate, equals(0.0));
    });

    test('mixed: 2 TURN, 8 direct → rate 0.2', () {
      for (var i = 0; i < 8; i++) {
        kpi.recordSessionType(isTurnRelayed: false);
      }
      kpi.recordSessionType(isTurnRelayed: true);
      kpi.recordSessionType(isTurnRelayed: true);
      expect(kpi.turnRelayRate, closeTo(0.2, 1e-9));
    });
  });

  // ── §6.2.3 P50/P95 move RTT ──────────────────────────────────────────────
  group('6.2.3 P50/P95 move RTT', () {
    test('null before any sample', () {
      expect(kpi.rttP50, isNull);
      expect(kpi.rttP95, isNull);
    });

    test('single sample: P50 = P95 = that sample', () {
      kpi.recordMoveRtt(42);
      expect(kpi.rttP50, equals(42));
      expect(kpi.rttP95, equals(42));
    });

    test('P50 and P95 correct for 100 uniform samples', () {
      for (var i = 1; i <= 100; i++) {
        kpi.recordMoveRtt(i);
      }
      expect(kpi.rttP50, closeTo(50, 1));
      expect(kpi.rttP95, greaterThanOrEqualTo(94));
    });

    test('P95 > P50 for skewed samples', () {
      // 90 fast values + 10 outliers → P50=10, P95=500.
      for (var i = 0; i < 90; i++) {
        kpi.recordMoveRtt(10);
      }
      for (var i = 0; i < 10; i++) {
        kpi.recordMoveRtt(500);
      }
      expect(kpi.rttP95!, greaterThan(kpi.rttP50!));
    });
  });

  // ── §6.2.4 MISMATCH rate ─────────────────────────────────────────────────
  group('6.2.4 MISMATCH rate', () {
    test('null before any moves', () {
      expect(kpi.mismatchRate, isNull);
    });

    test('zero mismatches → rate 0.0', () {
      kpi.recordMoves(count: 100000);
      expect(kpi.mismatchRate, equals(0.0));
    });

    test('1 mismatch in 100000 moves → rate 1e-5', () {
      kpi.recordMoves(count: 100000, mismatchCount: 1);
      expect(kpi.mismatchRate, closeTo(1e-5, 1e-10));
    });

    test('total moves accumulates across calls', () {
      kpi.recordMoves(count: 50000);
      kpi.recordMoves(count: 50000, mismatchCount: 1);
      expect(kpi.totalMoves, equals(100000));
      expect(kpi.totalMismatches, equals(1));
    });
  });

  // ── §6.2.5 BACKPRESSURE_DROP rate ────────────────────────────────────────
  group('6.2.5 backpressure drop rate', () {
    test('null before any frames', () {
      expect(kpi.backpressureDropRate, isNull);
    });

    test('no drops → rate 0.0', () {
      kpi.recordFrames(count: 1000);
      expect(kpi.backpressureDropRate, equals(0.0));
    });

    test('5 drops in 1000 frames → rate 0.005', () {
      kpi.recordFrames(count: 1000, dropCount: 5);
      expect(kpi.backpressureDropRate, closeTo(0.005, 1e-9));
    });
  });

  // ── §6.2.6 Push-wake redemption rate ─────────────────────────────────────
  group('6.2.6 push-wake redemption', () {
    test('null before any push wake', () {
      expect(kpi.pushRedemptionRate, isNull);
    });

    test('3 received, 2 redeemed → rate 2/3', () {
      kpi.recordPushWakeReceived();
      kpi.recordPushWakeReceived();
      kpi.recordPushWakeReceived();
      kpi.recordPushWakeRedeemed(timeToHandshakeMs: 800);
      kpi.recordPushWakeRedeemed(timeToHandshakeMs: 1200);
      expect(kpi.pushRedemptionRate, closeTo(2 / 3, 1e-9));
    });

    test('median push-to-handshake correct', () {
      kpi.recordPushWakeReceived();
      kpi.recordPushWakeReceived();
      kpi.recordPushWakeReceived();
      kpi.recordPushWakeRedeemed(timeToHandshakeMs: 500);
      kpi.recordPushWakeRedeemed(timeToHandshakeMs: 1000);
      kpi.recordPushWakeRedeemed(timeToHandshakeMs: 1500);
      expect(kpi.medianPushToHandshakeMs, equals(1000));
    });
  });

  // ── §6.2.7 Recovery-flow attempts vs successes ───────────────────────────
  group('6.2.7 recovery flow', () {
    test('null before any attempt', () {
      expect(kpi.recoverySuccessRate, isNull);
    });

    test('all successes → rate 1.0', () {
      kpi.recordRecoveryAttempt(succeeded: true);
      kpi.recordRecoveryAttempt(succeeded: true);
      expect(kpi.recoverySuccessRate, equals(1.0));
    });

    test('partial failures tracked', () {
      kpi.recordRecoveryAttempt(succeeded: true);
      kpi.recordRecoveryAttempt(succeeded: false);
      expect(kpi.recoveryAttempts, equals(2));
      expect(kpi.recoverySuccesses, equals(1));
      expect(kpi.recoverySuccessRate, closeTo(0.5, 1e-9));
    });
  });

  // ── §6.2.8 Battery & thermal anomalies ───────────────────────────────────
  group('6.2.8 battery & thermal anomalies', () {
    test('opt-in defaults to false', () {
      expect(kpi.batteryTelemetryOptIn, isFalse);
    });

    test('thermal warning ignored when opt-in false', () {
      kpi.recordThermalWarning();
      expect(kpi.thermalWarnings, equals(0));
    });

    test('battery saver ignored when opt-in false', () {
      kpi.recordBatterySaverActivation();
      expect(kpi.batterySaverActivations, equals(0));
    });

    test('thermal warning recorded after opt-in', () {
      kpi.setBatteryTelemetryOptIn(true);
      kpi.recordThermalWarning();
      expect(kpi.thermalWarnings, equals(1));
    });

    test('battery saver recorded after opt-in', () {
      kpi.setBatteryTelemetryOptIn(true);
      kpi.recordBatterySaverActivation();
      expect(kpi.batterySaverActivations, equals(1));
    });

    test('disabling opt-in stops further recording', () {
      kpi.setBatteryTelemetryOptIn(true);
      kpi.recordThermalWarning();
      kpi.setBatteryTelemetryOptIn(false);
      kpi.recordThermalWarning();
      expect(kpi.thermalWarnings, equals(1));
    });
  });

  // ── §6.2.9 Per-mod engine KPIs ───────────────────────────────────────────
  group('6.2.9 per-mod engine KPIs', () {
    test('returns null for unrecorded mod', () {
      expect(kpi.modWorstMissCp('heir'), isNull);
    });

    test('records worst-miss per mod', () {
      kpi.recordModKpiBatch(mod: 'heir', worstMissCp: 1.5, batchSize: 50);
      expect(kpi.modWorstMissCp('heir'), equals(1.5));
    });

    test('multiple mods tracked independently', () {
      kpi.recordModKpiBatch(mod: 'heir', worstMissCp: 1.2, batchSize: 50);
      kpi.recordModKpiBatch(
          mod: 'mercenary', worstMissCp: 0.8, batchSize: 50);
      expect(kpi.modWorstMissCp('heir'), equals(1.2));
      expect(kpi.modWorstMissCp('mercenary'), equals(0.8));
      expect(kpi.modKpiMods, containsAll(['heir', 'mercenary']));
    });
  });

  // ── Sink callback ─────────────────────────────────────────────────────────
  group('sink callback', () {
    test('sink receives snapshot on every mutation', () {
      final snapshots = <KpiSnapshot>[];
      final tracked = P2pKpiCollector(sink: snapshots.add);
      tracked.recordHandshakeAttempt(succeeded: true, elapsedMs: 500);
      tracked.recordMoveRtt(30);
      expect(snapshots, hasLength(2));
    });

    test('snapshot contains connectionSuccessRate key after attempt', () {
      final snapshots = <KpiSnapshot>[];
      final tracked = P2pKpiCollector(sink: snapshots.add);
      tracked.recordHandshakeAttempt(succeeded: true, elapsedMs: 500);
      expect(snapshots.last.containsKey('connectionSuccessRate'), isTrue);
    });
  });
}
