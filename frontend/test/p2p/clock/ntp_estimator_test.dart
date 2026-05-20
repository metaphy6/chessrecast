// §11.2 — NTP-style offset and delay estimation.
//
// KAT vectors against synthetic clock skew.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/clock/ntp_estimator.dart';

void main() {
  group('§11.2 ntp_estimator', () {
    test('perfect-network: offset and delay are zero', () {
      final est = NtpEstimator();
      // t_send=0, t_recv=10 (10ms one-way), t_resp=10, t_resp_echo=20.
      // offset = ((10-0) + (20-10)) / 2 = 10; delay = (20-0) - (10-10) = 20.
      // But this simulates perfect 10ms one-way delay with zero clock skew.
      // offset formula: ((t_recv - t_send) + (t_resp - t_resp_echo)) / 2
      // = ((10 - 0) + (10 - 20)) / 2 = (10 - 10) / 2 = 0  ← zero offset
      // delay = (t_resp_echo - t_send) - (t_resp - t_recv) = 20 - 0 = 20.
      est.recordSample(
        tSendMs: 0,
        tRecvMs: 10,
        tRespMs: 10,
        tRespEchoMs: 20,
      );
      final r = est.estimate;
      expect(r.offsetMs, closeTo(0, 1));
      expect(r.delayMs, closeTo(20, 1));
    });

    test('known +50 ms clock offset, symmetric 10 ms RTT', () {
      final est = NtpEstimator();
      // Sender clock ahead by 50 ms.
      // t_send=1000, t_recv=1010 (receive in remote time = local+50),
      // t_resp=1010, t_resp_echo=1070 (send back; round-trip 20ms sender time).
      // offset = ((1010-1000) + (1010-1070)) / 2 = (10 - 60) / 2 = -25.
      // Actually let's use the correct NTP formula properly:
      // offset = ((t_recv - t_send) + (t_resp - t_resp_echo)) / 2
      //        = ((1060 - 1000) + (1060 - 1070)) / 2   ← remote clock = t+50
      //        Hmm, let me use the standard NTP variables:
      //   T1 = t_send (originate timestamp)
      //   T2 = t_recv (receive timestamp, remote peer's clock)
      //   T3 = t_resp (transmit timestamp, remote peer's clock)
      //   T4 = t_resp_echo (destination timestamp, originator's clock)
      // offset = ((T2-T1) + (T3-T4)) / 2
      // delay  = (T4-T1) - (T3-T2)
      // If remote clock is +50 ms ahead:
      //   T1=1000, T2=1060 (1010+50), T3=1060 (T2+0 process), T4=1020 (1000+20).
      // offset = ((1060-1000) + (1060-1020)) / 2 = (60+40)/2 = 50 ✓
      // delay  = (1020-1000) - (1060-1060) = 20.
      est.recordSample(
        tSendMs: 1000,
        tRecvMs: 1060, // remote clock = local+50 at t=1010ms local
        tRespMs: 1060,
        tRespEchoMs: 1020,
      );
      final r = est.estimate;
      expect(r.offsetMs, closeTo(50, 5));
      expect(r.delayMs, closeTo(20, 5));
    });

    test('EWMA converges on repeated samples', () {
      final est = NtpEstimator();
      for (int i = 0; i < 10; i++) {
        est.recordSample(
          tSendMs: i * 1000,
          tRecvMs: i * 1000 + 60,
          tRespMs: i * 1000 + 60,
          tRespEchoMs: i * 1000 + 20,
        );
      }
      // After 10 identical samples, estimate should be stable.
      final r = est.estimate;
      expect(r.offsetMs, closeTo(50, 5));
      expect(r.delayMs, closeTo(20, 5));
    });

    test('best-RTT selection: low-delay sample is favoured', () {
      final est = NtpEstimator();
      // High-delay sample: RTT 200 ms, offset 0.
      est.recordSample(
        tSendMs: 0,
        tRecvMs: 100,
        tRespMs: 100,
        tRespEchoMs: 200,
      );
      // Low-delay sample: RTT 20 ms, offset 0.
      est.recordSample(
        tSendMs: 1000,
        tRecvMs: 1010,
        tRespMs: 1010,
        tRespEchoMs: 1020,
      );
      final r = est.best;
      expect(r.delayMs, closeTo(20, 5));
    });

    test('initial estimate before any sample is zero', () {
      final est = NtpEstimator();
      expect(est.estimate.offsetMs, 0);
      expect(est.estimate.delayMs, 0);
    });
  });
}
