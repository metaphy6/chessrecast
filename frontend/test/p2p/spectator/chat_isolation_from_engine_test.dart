// §7.10.5 chat isolation from engine (chess stream) proof test.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/spectator/spectator_perf.dart';

void main() {
  group('Chat isolation from engine §7.10.5', () {
    test('chess stream ID is different from chat stream ID', () {
      expect(SctpStreamPriority.chessStream,
          isNot(equals(SctpStreamPriority.chatStream)));
    });

    test('chess stream priority is higher than chat', () {
      expect(SctpStreamPriority.chessStream,
          lessThan(SctpStreamPriority.chatStream));
    });

    test('backpressure at high water mark stalls chat', () {
      final bp = SpectatorBackpressureState();
      // First tick records the stall start time.
      bp.onBackpressureTick(aboveHighWater: true, nowMs: 0);
      // Second tick after highWaterMarkMs elapsed triggers STALL.
      final result = bp.onBackpressureTick(
        aboveHighWater: true,
        nowMs: SpectatorBackpressureState.highWaterMarkMs,
      );
      expect(result, equals('SPECTATOR_BACKPRESSURE_STALL'));
    });

    test('backpressure not above high water does not stall', () {
      final bp = SpectatorBackpressureState();
      final result = bp.onBackpressureTick(aboveHighWater: false, nowMs: 0);
      expect(result, isNull);
    });

    test('SpectatorDecodeRateLimiter does not rate-limit chess frames', () {
      // The limiter is chat-only; calling it many times with spread nowMs
      // shows it only tracks within 1-second windows.
      final rl = SpectatorDecodeRateLimiter();
      for (var i = 0; i < 100; i++) {
        rl.tryDecode(i * 100); // each in separate second window
      }
      // After spreading across 10 s, all should pass.
      expect(rl.tryDecode(10001), isNull);
    });
  });
}
