// §9.9 T-MIN-001 — Age gate: users under 13 cannot create an account.
//
// Regulatory requirement (COPPA / GDPR-K): users must confirm they are ≥13
// before identity creation.  The gate is enforced at the service layer so
// it cannot be bypassed by skipping the UI.
library;

/// Minimum age (years) required to create an account.
const int kMinimumAgeYears = 13;

/// Result of the age-gate check.
enum AgeGateResult {
  /// User is old enough; proceed to account creation.
  allowed,

  /// User is under the minimum age; block account creation.
  blocked,

  /// Age information was not provided; block as a safe default.
  undisclosed,
}

/// Service-layer age gate (§9.9 T-MIN-001).
///
/// [birthYear], [birthMonth], [birthDay] are the user-provided date of birth.
/// [todayFn] is injectable for testing (defaults to [DateTime.now]).
AgeGateResult evaluateAgeGate({
  required int birthYear,
  required int birthMonth,
  required int birthDay,
  DateTime Function()? todayFn,
}) {
  final today = (todayFn ?? DateTime.now)();
  DateTime birthDate;
  try {
    birthDate = DateTime(birthYear, birthMonth, birthDay);
  } catch (_) {
    return AgeGateResult.undisclosed;
  }
  // Age = difference in whole years.
  var age = today.year - birthDate.year;
  final hadBirthdayThisYear =
      today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  if (!hadBirthdayThisYear) age--;
  if (age < 0) return AgeGateResult.undisclosed;
  return age >= kMinimumAgeYears ? AgeGateResult.allowed : AgeGateResult.blocked;
}
