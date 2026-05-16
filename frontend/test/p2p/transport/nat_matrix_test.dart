// §4.1 NAT type matrix proof test.
//
// Verifies that the NatMatrix helper correctly maps NAT-type pairs to the
// expected relay requirement:
//   symmetric × symmetric → TURN required
//   cone × any            → direct or srflx sufficient
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/transport/nat_matrix.dart';

void main() {
  group('NatMatrix §4.1', () {
    test('symmetric × symmetric requires TURN relay', () {
      expect(
        NatMatrix.requiresTurn(
            NatType.symmetric, NatType.symmetric),
        isTrue,
      );
    });

    test('fullCone × fullCone does not require TURN', () {
      expect(
        NatMatrix.requiresTurn(NatType.fullCone, NatType.fullCone),
        isFalse,
      );
    });

    test('fullCone × symmetric does not require TURN (cone side has srflx)', () {
      expect(
        NatMatrix.requiresTurn(NatType.fullCone, NatType.symmetric),
        isFalse,
      );
    });

    test('portRestrictedCone × portRestrictedCone does not require TURN', () {
      expect(
        NatMatrix.requiresTurn(
            NatType.portRestrictedCone, NatType.portRestrictedCone),
        isFalse,
      );
    });

    test('all enum values are mapped (no missing entry)', () {
      for (final a in NatType.values) {
        for (final b in NatType.values) {
          // Just calling it must not throw.
          NatMatrix.requiresTurn(a, b);
        }
      }
    });

    test('NatMatrix describes 4 NAT types', () {
      expect(NatType.values.length, equals(4));
    });
  });
}
