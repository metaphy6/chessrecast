// T-MIN-001 §9.9 — Age gate: users under 13 cannot create an account.
//
// Proof: evaluateAgeGate() returns blocked for users under 13, allowed for
// users ≥ 13, and undisclosed for invalid inputs.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/age_gate.dart';

void main() {
  // Fixed reference date for all tests.
  final today = DateTime(2025, 6, 1);
  DateTime Function() fakeTodayFn() => () => today;

  group('T-MIN-001 §9.9 — Age gate (minimum 13 years)', () {
    test('kMinimumAgeYears is 13', () {
      expect(kMinimumAgeYears, equals(13));
    });

    test('user exactly 13 years old today is allowed', () {
      // Born 2012-06-01; today is 2025-06-01 → exactly 13.
      final result = evaluateAgeGate(
        birthYear: 2012, birthMonth: 6, birthDay: 1,
        todayFn: fakeTodayFn(),
      );
      expect(result, equals(AgeGateResult.allowed));
    });

    test('user who turns 13 tomorrow is blocked', () {
      // Born 2012-06-02; today is 2025-06-01 → 12 years old.
      final result = evaluateAgeGate(
        birthYear: 2012, birthMonth: 6, birthDay: 2,
        todayFn: fakeTodayFn(),
      );
      expect(result, equals(AgeGateResult.blocked));
    });

    test('user aged 25 is allowed', () {
      final result = evaluateAgeGate(
        birthYear: 2000, birthMonth: 1, birthDay: 1,
        todayFn: fakeTodayFn(),
      );
      expect(result, equals(AgeGateResult.allowed));
    });

    test('user aged 12 is blocked', () {
      final result = evaluateAgeGate(
        birthYear: 2013, birthMonth: 6, birthDay: 2,
        todayFn: fakeTodayFn(),
      );
      expect(result, equals(AgeGateResult.blocked));
    });

    test('future birth date returns undisclosed', () {
      // Born 2030-01-01 — birth date in the future is invalid.
      final result = evaluateAgeGate(
        birthYear: 2030, birthMonth: 1, birthDay: 1,
        todayFn: fakeTodayFn(),
      );
      // age will be negative → undisclosed (safe default).
      expect(result, equals(AgeGateResult.undisclosed));
    });

    test('birthday earlier in the year is counted correctly', () {
      // Born 2011-01-01; today is 2025-06-01 → 14 years old.
      final result = evaluateAgeGate(
        birthYear: 2011, birthMonth: 1, birthDay: 1,
        todayFn: fakeTodayFn(),
      );
      expect(result, equals(AgeGateResult.allowed));
    });

    test('birthday later in the year is counted correctly', () {
      // Born 2012-12-31; today is 2025-06-01 → 12 years old (birthday not yet).
      final result = evaluateAgeGate(
        birthYear: 2012, birthMonth: 12, birthDay: 31,
        todayFn: fakeTodayFn(),
      );
      expect(result, equals(AgeGateResult.blocked));
    });
  });
}
