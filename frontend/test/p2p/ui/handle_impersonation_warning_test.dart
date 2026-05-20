// T-HDL-001 §9.10 — Handle impersonation warning.
//
// Proof: evaluateHandle() returns possibleImpersonation for handles resembling
// protected patterns, and safe for ordinary handles.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/ui/handle_impersonation.dart';

void main() {
  group('T-HDL-001 §9.10 — Handle impersonation detection', () {
    test('kProtectedHandlePatterns includes admin and chessrecast', () {
      expect(kProtectedHandlePatterns, contains('admin'));
      expect(kProtectedHandlePatterns, contains('chessrecast'));
      expect(kProtectedHandlePatterns, contains('moderator'));
    });

    test('exact "admin" handle returns possibleImpersonation', () {
      expect(evaluateHandle('admin'),
          equals(HandleImpersonationRisk.possibleImpersonation));
    });

    test('"Admin" (mixed case) returns possibleImpersonation', () {
      expect(evaluateHandle('Admin'),
          equals(HandleImpersonationRisk.possibleImpersonation));
    });

    test('"CHESSRECAST" (uppercase) returns possibleImpersonation', () {
      expect(evaluateHandle('CHESSRECAST'),
          equals(HandleImpersonationRisk.possibleImpersonation));
    });

    test('"admin_chess" (starts with admin) returns possibleImpersonation', () {
      expect(evaluateHandle('admin_chess'),
          equals(HandleImpersonationRisk.possibleImpersonation));
    });

    test('"chess_admin" (ends with admin) returns possibleImpersonation', () {
      expect(evaluateHandle('chess_admin'),
          equals(HandleImpersonationRisk.possibleImpersonation));
    });

    test('"official_player" (starts with official) returns possibleImpersonation', () {
      expect(evaluateHandle('official_player'),
          equals(HandleImpersonationRisk.possibleImpersonation));
    });

    test('ordinary handle "alice" returns safe', () {
      expect(evaluateHandle('alice'), equals(HandleImpersonationRisk.safe));
    });

    test('ordinary handle "Bob42" returns safe', () {
      expect(evaluateHandle('Bob42'), equals(HandleImpersonationRisk.safe));
    });

    test('empty handle returns safe (no match)', () {
      expect(evaluateHandle(''), equals(HandleImpersonationRisk.safe));
    });

    test('warning message mentions seed phrase', () {
      expect(
        kHandleImpersonationWarning.toLowerCase(),
        contains('seed'),
      );
    });
  });
}
