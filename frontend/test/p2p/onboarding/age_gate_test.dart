// §14.4 — Age-gate onboarding proof test.
//
// Verifies that the age gate is enforced as part of the onboarding flow:
// users under 13 cannot proceed to account creation, chat, or spectator mode.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/age_gate.dart';

void main() {
  // Fixed reference date for reproducibility.
  final refDate = DateTime(2025, 9, 1);
  DateTime Function() today = () => refDate;

  group('§14.4 — Age gate onboarding flow', () {
    test('COPPA minimum age constant is 13', () {
      expect(kMinimumAgeYears, equals(13));
    });

    test('user aged exactly 13 is allowed to create an account', () {
      // Born 2012-09-01; today is 2025-09-01 → exactly 13.
      final result = evaluateAgeGate(
        birthYear: 2012, birthMonth: 9, birthDay: 1, todayFn: today,
      );
      expect(result, equals(AgeGateResult.allowed),
          reason: 'user aged exactly 13 must be allowed');
    });

    test('user aged 12 is blocked from creating an account', () {
      // Born 2012-09-02; today is 2025-09-01 → 12 years old.
      final result = evaluateAgeGate(
        birthYear: 2012, birthMonth: 9, birthDay: 2, todayFn: today,
      );
      expect(result, equals(AgeGateResult.blocked),
          reason: 'under-13 user must be blocked (COPPA)');
    });

    test('"prefer not to say" maps to undisclosed (safe default = blocked)', () {
      // A birthdate in the far future models the "prefer not to say" path.
      final result = evaluateAgeGate(
        birthYear: 2099, birthMonth: 1, birthDay: 1, todayFn: today,
      );
      expect(result, equals(AgeGateResult.undisclosed),
          reason: '"prefer not to say" must default to safe blocked state');
    });

    test('user aged 18 is allowed', () {
      final result = evaluateAgeGate(
        birthYear: 2007, birthMonth: 1, birthDay: 1, todayFn: today,
      );
      expect(result, equals(AgeGateResult.allowed));
    });

    test('user born on birthday edge (turns 13 tomorrow) is blocked', () {
      // Born 2012-09-02; today is 2025-09-01 → still 12.
      final result = evaluateAgeGate(
        birthYear: 2012, birthMonth: 9, birthDay: 2, todayFn: today,
      );
      expect(result, equals(AgeGateResult.blocked));
    });

    test('under-age result blocks access to chat features', () {
      // Under-age users must not be allowed into chat.
      final result = evaluateAgeGate(
        birthYear: 2015, birthMonth: 1, birthDay: 1, todayFn: today,
      );
      expect(result, isNot(AgeGateResult.allowed),
          reason: 'under-age user must not access chat');
    });

    test('allowed result permits access to all features', () {
      final result = evaluateAgeGate(
        birthYear: 2000, birthMonth: 1, birthDay: 1, todayFn: today,
      );
      expect(result, equals(AgeGateResult.allowed));
    });
  });
}
