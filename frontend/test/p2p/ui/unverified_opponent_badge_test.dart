import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// TOFU badge widget contract tests (§2.9.bullet-3).
///
/// Verifies the business-logic contract behind the unverified-opponent badge.
/// Widget rendering tests live in frontend/test/p2p/ui/; these tests cover
/// the data model that drives the badge.
void main() {
  group('Unverified opponent badge — data model (§2.9)', () {
    late VerifiedContacts contacts;
    late Uint8List opponentPubKey;

    setUp(() {
      contacts = VerifiedContacts();
      opponentPubKey = DeviceIdentity.generate().publicKey;
    });

    test('unknown contact → lookup returns null (TOFU badge)', () {
      // lookup by a freshly-generated key returns null → UI shows TOFU warning
      final stranger = DeviceIdentity.generate().publicKey;
      final stored = contacts.lookup(stranger);
      expect(
        stored,
        isNull,
        reason: 'Null lookup must trigger unverified TOFU badge in UI',
      );
    });

    test('verified contact → lookup returns non-null (green badge)', () {
      contacts.verify(
        theirPublicKey: opponentPubKey,
        method: VerificationMethod.safetyNumbers,
      );
      final stored = contacts.lookup(opponentPubKey);
      expect(stored, isNotNull);
      expect(stored!.method, equals(VerificationMethod.safetyNumbers));
    });

    test('verification method is persisted and readable by UI', () {
      contacts.verify(
        theirPublicKey: opponentPubKey,
        method: VerificationMethod.qr,
      );
      final stored = contacts.lookup(opponentPubKey);
      expect(stored?.method, equals(VerificationMethod.qr));
    });

    test(
      'changed key → ContactKeyChangeResult.changed triggers red banner',
      () {
        contacts.verify(
          theirPublicKey: opponentPubKey,
          method: VerificationMethod.safetyNumbers,
        );
        final originalFp = DeviceFingerprint.compute(opponentPubKey);
        final newKey = DeviceIdentity.generate().publicKey;
        final result = contacts.checkKeyChange(
          theirPublicKey: newKey,
          theirKnownFingerprint: originalFp,
        );
        expect(
          result,
          equals(ContactKeyChangeResult.changed),
          reason:
              'UI must receive ContactKeyChangeResult.changed for red banner',
        );
      },
    );

    test('VerificationMethod has both safetyNumbers and qr variants', () {
      expect(
        VerificationMethod.values,
        containsAll([VerificationMethod.safetyNumbers, VerificationMethod.qr]),
      );
    });
  });
}
