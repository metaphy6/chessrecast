import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('SafetyNumbers — §2.9 TOFU verification', () {
    test('compute returns 30-digit string with 5 groups of 5', () {
      final alice = DeviceIdentity.generate();
      final bob = DeviceIdentity.generate();
      final sn = SafetyNumbers.compute(alice.publicKey, bob.publicKey);
      // Format: "XXXXX XXXXX XXXXX XXXXX XXXXX XXXXX" (30 digits, 5 spaces)
      expect(sn.length, equals(35)); // 30 digits + 5 spaces
      final groups = sn.split(' ');
      expect(groups.length, equals(6));
      for (final g in groups) {
        expect(g.length, equals(5));
        expect(RegExp(r'^\d{5}$').hasMatch(g), isTrue);
      }
    });

    test('compute is symmetric: SafetyNumbers(A,B) == SafetyNumbers(B,A)', () {
      final alice = DeviceIdentity.generate();
      final bob = DeviceIdentity.generate();
      final sn1 = SafetyNumbers.compute(alice.publicKey, bob.publicKey);
      final sn2 = SafetyNumbers.compute(bob.publicKey, alice.publicKey);
      expect(sn1, equals(sn2));
    });

    test('different peers produce different safety numbers', () {
      final alice = DeviceIdentity.generate();
      final bob = DeviceIdentity.generate();
      final charlie = DeviceIdentity.generate();
      final sn1 = SafetyNumbers.compute(alice.publicKey, bob.publicKey);
      final sn2 = SafetyNumbers.compute(alice.publicKey, charlie.publicKey);
      expect(sn1, isNot(equals(sn2)));
    });

    test('same peer pair always produces same safety number', () {
      final alice = DeviceIdentity.generate();
      final bob = DeviceIdentity.generate();
      final sn1 = SafetyNumbers.compute(alice.publicKey, bob.publicKey);
      final sn2 = SafetyNumbers.compute(alice.publicKey, bob.publicKey);
      expect(sn1, equals(sn2));
    });
  });
}
