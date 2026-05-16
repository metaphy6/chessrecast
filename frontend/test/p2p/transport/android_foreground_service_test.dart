// §4.3 Android foreground service lifecycle policy (hermetic model test).
//
// Verifies that AppLifecyclePolicy:
//   - recommends foreground service on Android in-game
//   - does not start foreground service when no game is active
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/app_lifecycle_policy.dart';

void main() {
  group('AppLifecyclePolicy §4.3 Android', () {
    test('foreground service required when game is active', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.android);
      expect(policy.requiresForegroundService(gameActive: true), isTrue);
    });

    test('foreground service not required when no game is active', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.android);
      expect(policy.requiresForegroundService(gameActive: false), isFalse);
    });

    test('iOS policy does not use foreground service (uses push instead)', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.iOS);
      expect(policy.requiresForegroundService(gameActive: true), isFalse);
    });

    test('iOS policy uses graceful close on suspension', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.iOS);
      expect(policy.suspensionStrategy, equals(SuspensionStrategy.gracefulClose));
    });

    test('Android policy uses foreground keep-alive on suspension', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.android);
      expect(policy.suspensionStrategy,
          equals(SuspensionStrategy.foregroundService));
    });
  });
}
