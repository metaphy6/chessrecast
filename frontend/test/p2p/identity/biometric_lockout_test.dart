import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('BiometricLockout — §2.1', () {
    test('recordSuccess resets consecutive failure count', () {
      final lockout = BiometricLockout(maxFailures: 5);
      lockout.recordFailure(onWipe: () {});
      lockout.recordFailure(onWipe: () {});
      expect(lockout.consecutiveFailures, equals(2));
      lockout.recordSuccess();
      expect(lockout.consecutiveFailures, equals(0));
    });

    test('onWipe is called after maxFailures consecutive failures', () {
      bool wiped = false;
      final lockout = BiometricLockout(maxFailures: 3);
      lockout.recordFailure(onWipe: () {});
      lockout.recordFailure(onWipe: () {});
      lockout.recordFailure(
        onWipe: () {
          wiped = true;
        },
      );
      expect(wiped, isTrue);
      expect(lockout.wiped, isTrue);
    });

    test('onWipe is not called before maxFailures', () {
      bool wiped = false;
      final lockout = BiometricLockout(maxFailures: 5);
      for (int i = 0; i < 4; i++) {
        lockout.recordFailure(
          onWipe: () {
            wiped = true;
          },
        );
      }
      expect(wiped, isFalse);
    });

    test('success resets counter so reaching max requires starting over', () {
      bool wiped = false;
      final lockout = BiometricLockout(maxFailures: 3);
      lockout.recordFailure(onWipe: () {});
      lockout.recordFailure(onWipe: () {});
      lockout.recordSuccess(); // resets counter
      lockout.recordFailure(onWipe: () {});
      lockout.recordFailure(
        onWipe: () {
          wiped = true;
        },
      );
      expect(wiped, isFalse); // only 2 consecutive since last success
    });

    test('once wiped, further failures are no-ops', () {
      int wipeCount = 0;
      final lockout = BiometricLockout(maxFailures: 2);
      lockout.recordFailure(
        onWipe: () {
          wipeCount++;
        },
      );
      lockout.recordFailure(
        onWipe: () {
          wipeCount++;
        },
      );
      // Already wiped after 2
      lockout.recordFailure(
        onWipe: () {
          wipeCount++;
        },
      );
      expect(wipeCount, equals(1)); // onWipe called exactly once
      expect(lockout.wiped, isTrue);
    });

    test('reset clears wiped state for account recovery flow', () {
      final lockout = BiometricLockout(maxFailures: 2);
      lockout.recordFailure(onWipe: () {});
      lockout.recordFailure(onWipe: () {});
      expect(lockout.wiped, isTrue);
      lockout.reset();
      expect(lockout.wiped, isFalse);
      expect(lockout.consecutiveFailures, equals(0));
    });

    test('default maxFailures is 10', () {
      final lockout = BiometricLockout();
      expect(lockout.maxFailures, equals(10));
    });
  });
}
