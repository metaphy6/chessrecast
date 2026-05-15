import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Contact pubkey change warning tests (§2.9.bullet-4).
///
/// When a previously-verified contact's public key changes, the local
/// [VerifiedContacts] store must signal a key-change event.
void main() {
  group('Contact pubkey change warning (§2.9)', () {
    test('same pubkey → ContactKeyChangeResult.same', () {
      final contacts = VerifiedContacts();
      final pk = DeviceIdentity.generate().publicKey;
      contacts.verify(
        theirPublicKey: pk,
        method: VerificationMethod.safetyNumbers,
      );
      final fp = DeviceFingerprint.compute(pk);
      final result = contacts.checkKeyChange(
        theirPublicKey: pk,
        theirKnownFingerprint: fp,
      );
      expect(result, equals(ContactKeyChangeResult.same));
    });

    test('different pubkey → ContactKeyChangeResult.changed', () {
      final contacts = VerifiedContacts();
      final pk1 = DeviceIdentity.generate().publicKey;
      final pk2 = DeviceIdentity.generate().publicKey;
      contacts.verify(
        theirPublicKey: pk1,
        method: VerificationMethod.safetyNumbers,
      );
      final fp1 = DeviceFingerprint.compute(pk1);
      // Check new key against old fingerprint
      final result = contacts.checkKeyChange(
        theirPublicKey: pk2,
        theirKnownFingerprint: fp1,
      );
      expect(result, equals(ContactKeyChangeResult.changed));
    });

    test('unknown contact → ContactKeyChangeResult.unknown', () {
      final contacts = VerifiedContacts();
      final pk = DeviceIdentity.generate().publicKey;
      final result = contacts.checkKeyChange(
        theirPublicKey: pk,
        theirKnownFingerprint: DeviceFingerprint.compute(pk),
      );
      expect(result, equals(ContactKeyChangeResult.unknown));
    });

    test('re-verify after key change stores new key', () {
      final contacts = VerifiedContacts();
      final pk1 = DeviceIdentity.generate().publicKey;
      final pk2 = DeviceIdentity.generate().publicKey;
      contacts.verify(theirPublicKey: pk1, method: VerificationMethod.qr);
      contacts.verify(theirPublicKey: pk2, method: VerificationMethod.qr);
      // pk2 lookup should succeed
      final stored = contacts.lookup(pk2);
      expect(stored, isNotNull);
      expect(stored!.publicKey, equals(pk2));
    });

    test('key change result values include same, changed, unknown', () {
      expect(
        ContactKeyChangeResult.values,
        containsAll([
          ContactKeyChangeResult.same,
          ContactKeyChangeResult.changed,
          ContactKeyChangeResult.unknown,
        ]),
      );
    });
  });
}
