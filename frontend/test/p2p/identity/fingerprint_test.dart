import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('DeviceFingerprint — §2.1', () {
    test('compute returns 12-character string (format: xxxx-xxxx-xx)', () {
      final id = DeviceIdentity.generate();
      final fp = DeviceFingerprint.compute(id.publicKey);
      expect(fp.length, equals(12));
      expect(fp[4], equals('-'));
      expect(fp[9], equals('-'));
    });

    test('fingerprint is deterministic from public key', () {
      final id = DeviceIdentity.generate();
      final fp1 = DeviceFingerprint.compute(id.publicKey);
      final fp2 = DeviceFingerprint.compute(id.publicKey);
      expect(fp1, equals(fp2));
    });

    test('different public keys produce different fingerprints', () {
      final id1 = DeviceIdentity.generate();
      final id2 = DeviceIdentity.generate();
      final fp1 = DeviceFingerprint.compute(id1.publicKey);
      final fp2 = DeviceFingerprint.compute(id2.publicKey);
      expect(fp1, isNot(equals(fp2)));
    });

    test('fingerprint only contains lowercase base32 chars and hyphens', () {
      for (int i = 0; i < 10; i++) {
        final id = DeviceIdentity.generate();
        final fp = DeviceFingerprint.compute(id.publicKey);
        final withoutHyphens = fp.replaceAll('-', '');
        final validBase32 = RegExp(r'^[a-z2-7]+$');
        expect(
          validBase32.hasMatch(withoutHyphens),
          isTrue,
          reason: 'Fingerprint contains invalid chars: $fp',
        );
      }
    });

    test('fingerprint groups are 4-4-2 chars', () {
      final id = DeviceIdentity.generate();
      final fp = DeviceFingerprint.compute(id.publicKey);
      final parts = fp.split('-');
      expect(parts.length, equals(3));
      expect(parts[0].length, equals(4));
      expect(parts[1].length, equals(4));
      expect(parts[2].length, equals(2));
    });
  });
}
