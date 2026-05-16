// §4.3 iOS NSE (Notification Service Extension) wakeup payload test.
//
// The NSE receives a push containing only a session_hint (no game data).
// This test verifies the payload model is correctly structured and that
// the wakeup payload contains no plaintext game data.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/app_lifecycle_policy.dart';

void main() {
  group('iOS NSE §4.3', () {
    test('wakeup payload contains session_hint not game data', () {
      final payload = PushWakeupPayload(sessionHint: 'abc123');
      expect(payload.sessionHint, equals('abc123'));
      expect(payload.containsGameData, isFalse);
    });

    test('session_hint is an opaque token (not a raw session_id)', () {
      final payload = PushWakeupPayload(sessionHint: 'random-opaque-token');
      // Must not be a session UUID — it's a redeem-once hint
      expect(payload.isRedeemOnce, isTrue);
    });

    test('wakeup payload serialises to JSON with aps.content-available=1', () {
      final payload = PushWakeupPayload(sessionHint: 'tok');
      final json = payload.toApnsJson();
      expect(json['aps']['content-available'], equals(1));
      expect(json['token'], equals('tok'));
    });

    test('NSE pre-warm strategy is best-effort (not blocking)', () {
      expect(NsePlatformPolicy.preWarmStrategy,
          equals(PreWarmStrategy.bestEffort));
    });
  });
}
