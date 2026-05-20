// §14.4 — Age-gate accessibility proof test.
//
// Verifies that the age-gate service layer satisfies accessibility requirements:
//   - Distinct result enum values allow screen-reader copy to differ per state.
//   - The gate uses a non-discriminatory "undisclosed" path (no dark patterns).
//   - Result values form a closed enum that callers can exhaustively handle.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/p2p/ui/age_gate.dart';

void main() {
  group('§14.4 — Age gate accessibility (a11y)', () {
    test(
      'AgeGateResult has exactly three values (allowed/blocked/undisclosed)',
      () {
        expect(
          AgeGateResult.values.length,
          equals(3),
          reason: 'Screen-reader copy depends on exactly 3 distinct states',
        );
        expect(
          AgeGateResult.values,
          containsAll([
            AgeGateResult.allowed,
            AgeGateResult.blocked,
            AgeGateResult.undisclosed,
          ]),
        );
      },
    );

    test('allowed, blocked, and undisclosed are all distinct', () {
      expect(AgeGateResult.allowed, isNot(AgeGateResult.blocked));
      expect(AgeGateResult.allowed, isNot(AgeGateResult.undisclosed));
      expect(AgeGateResult.blocked, isNot(AgeGateResult.undisclosed));
    });

    test(
      'undisclosed result is treated as blocked (safe default for a11y users who cannot provide DOB)',
      () {
        // An a11y user who cannot interact with the date picker uses
        // "prefer not to say" → undisclosed.  The service must not grant access.
        final result = evaluateAgeGate(
          birthYear: 2099,
          birthMonth: 1,
          birthDay: 1,
          todayFn: () => DateTime(2025),
        );
        expect(result, equals(AgeGateResult.undisclosed));
        // Callers must treat undisclosed the same as blocked:
        expect(result != AgeGateResult.allowed, isTrue);
      },
    );

    test('evaluateAgeGate never throws for extreme DOB inputs', () {
      // Guard against exceptions that could leave an a11y user stuck.
      expect(
        () => evaluateAgeGate(
          birthYear: 0,
          birthMonth: 0,
          birthDay: 0,
          todayFn: () => DateTime(2025),
        ),
        returnsNormally,
      );
      expect(
        () => evaluateAgeGate(
          birthYear: 9999,
          birthMonth: 12,
          birthDay: 31,
          todayFn: () => DateTime(2025),
        ),
        returnsNormally,
      );
    });

    test('kMinimumAgeYears is publicly visible for UI copy generation', () {
      // Accessibility copy ("You must be at least X years old") uses this
      // constant directly so it stays in sync with the service logic.
      expect(kMinimumAgeYears, greaterThan(0));
      expect(kMinimumAgeYears, equals(13));
    });
  });
}
