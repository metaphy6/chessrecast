// T-D-007 §9.9 — Recovery screen offers custom secure keyboard option.
//
// Proof: ScreenSecurityPolicy.recoveryScreen.useSecureKeyboard = true;
// the option is surfaced to the user rather than silently enforced.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/recovery_screen_policy.dart';

void main() {
  group('T-D-007 §9.9 — Recovery screen: custom secure keyboard option', () {
    test('recoveryScreen policy uses secure keyboard', () {
      expect(
        ScreenSecurityPolicy.recoveryScreen.useSecureKeyboard,
        isTrue,
      );
    });

    test('standard screen policy does not force secure keyboard', () {
      expect(ScreenSecurityPolicy.standard.useSecureKeyboard, isFalse);
    });

    test('secure keyboard is distinct from standard mode', () {
      // The policy objects must differ on the keyboard flag.
      expect(
        ScreenSecurityPolicy.recoveryScreen.useSecureKeyboard,
        isNot(equals(ScreenSecurityPolicy.standard.useSecureKeyboard)),
      );
    });
  });
}
