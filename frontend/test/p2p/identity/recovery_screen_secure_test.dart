// T-D-006 §9.9 — Recovery screen applies FLAG_SECURE; screenshots disabled.
//
// Proof: ScreenSecurityPolicy.recoveryScreen has screenshotsDisabled=true and
// useSecureKeyboard=true; assertRecoveryRequirements() enforces both.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/recovery_screen_policy.dart';

void main() {
  group('T-D-006 §9.9 — Recovery screen security policy', () {
    test('recoveryScreen policy has screenshotsDisabled = true', () {
      expect(
        ScreenSecurityPolicy.recoveryScreen.screenshotsDisabled,
        isTrue,
        reason: 'FLAG_SECURE / allowScreenshot=false must be set',
      );
    });

    test('recoveryScreen policy has useSecureKeyboard = true', () {
      expect(
        ScreenSecurityPolicy.recoveryScreen.useSecureKeyboard,
        isTrue,
        reason: 'secure keyboard must be offered to prevent IME logging',
      );
    });

    test('standard policy does not disable screenshots', () {
      expect(ScreenSecurityPolicy.standard.screenshotsDisabled, isFalse);
    });

    test('assertRecoveryRequirements passes for recoveryScreen policy', () {
      expect(
        () => ScreenSecurityPolicy.assertRecoveryRequirements(
            ScreenSecurityPolicy.recoveryScreen),
        returnsNormally,
      );
    });

    test('assertRecoveryRequirements fails for policy with screenshots allowed', () {
      const insecure = ScreenSecurityPolicy(
        screenshotsDisabled: false,
        useSecureKeyboard: true,
      );
      expect(
        () => ScreenSecurityPolicy.assertRecoveryRequirements(insecure),
        throwsA(isA<AssertionError>()),
      );
    });

    test('assertRecoveryRequirements fails for policy without secure keyboard', () {
      const insecure = ScreenSecurityPolicy(
        screenshotsDisabled: true,
        useSecureKeyboard: false,
      );
      expect(
        () => ScreenSecurityPolicy.assertRecoveryRequirements(insecure),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
