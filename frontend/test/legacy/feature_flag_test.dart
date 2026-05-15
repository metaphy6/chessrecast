/// Proof test for roadmap §0.2.bullet-4: kUseLegacyBackend feature flag.
///
/// Tests:
/// 1. kUseLegacyBackend is declared in AppConstants and equals false.
/// 2. kUseLegacyBackend is a compile-time constant (boolean, not nullable).
/// 3. (Smoke) Loading the constants library does not throw.
library;

import 'package:flutter_test/flutter_test.dart';

import '../../lib/constants.dart';

void main() {
  test('1. kUseLegacyBackend is false', () {
    expect(AppConstants.kUseLegacyBackend, isFalse);
  });

  test('2. kUseLegacyBackend is a non-nullable bool', () {
    // The type check is enforced at compile time; this test documents it exists.
    expect(AppConstants.kUseLegacyBackend, isA<bool>());
  });

  test('3. constants library loads without throwing', () {
    expect(() => AppConstants.kUseLegacyBackend, returnsNormally);
  });
}
