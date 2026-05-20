// T-P-011 §9.10 — Anti-rollback high-water mark for identity key version.
//
// Proof: AntiRollbackPolicy.enroll() allows strictly increasing versions and
// throws RollbackAttemptError for equal or lower versions.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/anti_rollback.dart';

void main() {
  group('T-P-011 §9.10 — Anti-rollback high-water mark', () {
    test('enrolling version 1 on fresh policy (hwm=0) succeeds', () {
      final policy = AntiRollbackPolicy(0);
      expect(() => policy.enroll(1), returnsNormally);
      expect(policy.highWaterMark, equals(1));
    });

    test('enrolling strictly increasing versions advances the hwm', () {
      final policy = AntiRollbackPolicy(0);
      policy.enroll(1);
      policy.enroll(5);
      policy.enroll(10);
      expect(policy.highWaterMark, equals(10));
    });

    test('re-enrolling the same version throws RollbackAttemptError', () {
      final policy = AntiRollbackPolicy(3);
      expect(
        () => policy.enroll(3),
        throwsA(isA<RollbackAttemptError>()),
        reason: 'same version = rollback attempt',
      );
    });

    test('enrolling a lower version throws RollbackAttemptError', () {
      final policy = AntiRollbackPolicy(5);
      expect(
        () => policy.enroll(2),
        throwsA(isA<RollbackAttemptError>()),
        reason: 'downgrade must be refused',
      );
    });

    test('RollbackAttemptError carries both attempted version and hwm', () {
      final policy = AntiRollbackPolicy(7);
      try {
        policy.enroll(3);
        fail('Expected RollbackAttemptError');
      } on RollbackAttemptError catch (e) {
        expect(e.attemptedVersion, equals(3));
        expect(e.highWaterMark, equals(7));
        expect(e.toString(), contains('3'));
        expect(e.toString(), contains('7'));
      }
    });

    test('hwm does not change after a rejected enrollment', () {
      final policy = AntiRollbackPolicy(5);
      try {
        policy.enroll(3);
      } on RollbackAttemptError {
        // expected
      }
      expect(policy.highWaterMark, equals(5),
          reason: 'failed enrollment must not update hwm');
    });

    test('isAllowed returns true only for versions strictly above hwm', () {
      final policy = AntiRollbackPolicy(4);
      expect(policy.isAllowed(5), isTrue);
      expect(policy.isAllowed(4), isFalse);
      expect(policy.isAllowed(3), isFalse);
    });
  });
}
