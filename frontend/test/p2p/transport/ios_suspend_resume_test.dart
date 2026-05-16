// §4.3 iOS suspend/resume lifecycle policy (hermetic model test).
//
// Verifies the iOS-specific: graceful close on suspend + push wakeup re-establishment.
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/app_lifecycle_policy.dart';

void main() {
  group('AppLifecyclePolicy §4.3 iOS', () {
    test('iOS graceful close does not abuse VoIP background mode', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.iOS);
      expect(policy.usesVoipBackground, isFalse);
    });

    test('iOS re-establishes via push wakeup after suspend', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.iOS);
      expect(policy.reestablishmentMethod,
          equals(ReestablishmentMethod.pushWakeup));
    });

    test('Android re-establishes via foreground service (no push needed)', () {
      final policy = AppLifecyclePolicy(platform: AppPlatform.android);
      expect(policy.reestablishmentMethod,
          equals(ReestablishmentMethod.foregroundService));
    });

    test('push wakeup P95 budget is 5 seconds', () {
      expect(AppLifecyclePolicy.pushWakeupP95BudgetMs, equals(5000));
    });
  });
}
