import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('VerifiedContacts — persistence & key change detection (§2.9)', () {
    test('verify stores a contact and lookup returns it', () {
      final contacts = VerifiedContacts();
      final bob = DeviceIdentity.generate();
      contacts.verify(
        theirPublicKey: bob.publicKey,
        method: VerificationMethod.safetyNumbers,
      );
      final record = contacts.lookup(bob.publicKey);
      expect(record, isNotNull);
      expect(record!.method, equals(VerificationMethod.safetyNumbers));
    });

    test('lookup returns null for unknown contact', () {
      final contacts = VerifiedContacts();
      final bob = DeviceIdentity.generate();
      expect(contacts.lookup(bob.publicKey), isNull);
    });

    test('fingerprint matches DeviceFingerprint.compute', () {
      final contacts = VerifiedContacts();
      final bob = DeviceIdentity.generate();
      contacts.verify(
        theirPublicKey: bob.publicKey,
        method: VerificationMethod.qr,
      );
      final record = contacts.lookup(bob.publicKey)!;
      expect(
        record.fingerprint,
        equals(DeviceFingerprint.compute(bob.publicKey)),
      );
    });

    test('checkKeyChange returns same for same key', () {
      final contacts = VerifiedContacts();
      final bob = DeviceIdentity.generate();
      contacts.verify(
        theirPublicKey: bob.publicKey,
        method: VerificationMethod.safetyNumbers,
      );
      final fp = DeviceFingerprint.compute(bob.publicKey);
      final result = contacts.checkKeyChange(
        theirPublicKey: bob.publicKey,
        theirKnownFingerprint: fp,
      );
      expect(result, equals(ContactKeyChangeResult.same));
    });

    test('checkKeyChange returns unknown for unverified contact', () {
      final contacts = VerifiedContacts();
      final bob = DeviceIdentity.generate();
      final result = contacts.checkKeyChange(
        theirPublicKey: bob.publicKey,
        theirKnownFingerprint: DeviceFingerprint.compute(bob.publicKey),
      );
      expect(result, equals(ContactKeyChangeResult.unknown));
    });

    test('checkKeyChange returns changed when key rotated', () {
      final contacts = VerifiedContacts();
      final bob1 = DeviceIdentity.generate();
      final bob2 = DeviceIdentity.generate(); // Bob's new key
      // Verify Bob's original key
      contacts.verify(
        theirPublicKey: bob1.publicKey,
        method: VerificationMethod.safetyNumbers,
      );
      final originalFp = DeviceFingerprint.compute(bob1.publicKey);
      // Check with Bob's new (different) public key against old fingerprint
      final result = contacts.checkKeyChange(
        theirPublicKey: bob2.publicKey, // new key
        theirKnownFingerprint: originalFp, // old fingerprint
      );
      expect(result, equals(ContactKeyChangeResult.changed));
    });

    test('re-verify overwrites existing record', () {
      final contacts = VerifiedContacts();
      final bob = DeviceIdentity.generate();
      contacts.verify(
        theirPublicKey: bob.publicKey,
        method: VerificationMethod.safetyNumbers,
      );
      contacts.verify(
        theirPublicKey: bob.publicKey,
        method: VerificationMethod.qr,
      );
      final record = contacts.lookup(bob.publicKey)!;
      expect(record.method, equals(VerificationMethod.qr));
    });
  });
}
