// §6.5 Quality attribute proof tests (performance, stability, reliability).
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/telemetry/beta_kpis.dart';

void main() {
  // §6.5.1 Performance
  group('P2pPerformanceKpis §6.5.1', () {
    test('handshake timeout is 30 s', () {
      expect(P2pPerformanceKpis.handshakeTimeoutMs, equals(30000));
    });
    test('P95 RTT target is 300 ms', () {
      expect(P2pPerformanceKpis.moveRttP95TargetMs, equals(300));
    });
    test('direct-connect rate target is 60%', () {
      expect(
          P2pPerformanceKpis.directConnectRateTarget, closeTo(0.60, 1e-9));
    });
  });

  // §6.5.3 Stability
  group('P2pStabilityKpis §6.5.3', () {
    test('crash-free rate minimum is 99.9%', () {
      expect(P2pStabilityKpis.crashFreeRateMin, closeTo(0.999, 1e-9));
    });
  });

  // §6.5.4 Reliability
  group('P2pReliabilityKpis §6.5.4', () {
    test('zero MISMATCH events allowed', () {
      expect(P2pReliabilityKpis.maxMismatchEvents, equals(0));
    });
    test('1 mismatch is a reliability violation', () {
      expect(P2pReliabilityKpis.isReliabilityViolated(1), isTrue);
    });
    test('0 mismatches is not a violation', () {
      expect(P2pReliabilityKpis.isReliabilityViolated(0), isFalse);
    });
  });
}
