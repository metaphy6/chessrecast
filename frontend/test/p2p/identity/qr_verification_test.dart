import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// QR-code in-person verification tests (§2.9.bullet-2).
void main() {
  group('QR verification (§2.9)', () {
    late Uint8List pkAlice;
    late Uint8List pkBob;

    setUp(() {
      pkAlice = DeviceIdentity.generate().publicKey;
      pkBob = DeviceIdentity.generate().publicKey;
    });

    test(
      'verify() returns true when both peers see the same safety number',
      () {
        final number = SafetyNumbers.compute(pkAlice, pkBob);

        final alicePayload = QrVerificationPayload(
          myPublicKey: pkAlice,
          theirPublicKey: pkBob,
          expectedSafetyNumber: number,
        );
        final bobPayload = QrVerificationPayload(
          myPublicKey: pkBob,
          theirPublicKey: pkAlice,
          expectedSafetyNumber: number,
        );

        // Alice scans Bob's QR
        expect(alicePayload.verify(bobPayload), isTrue);
        // Bob scans Alice's QR
        expect(bobPayload.verify(alicePayload), isTrue);
      },
    );

    test('verify() returns false when safety numbers mismatch (MITM)', () {
      final mallory = DeviceIdentity.generate().publicKey;
      final realNumber = SafetyNumbers.compute(pkAlice, pkBob);
      final mitm = SafetyNumbers.compute(pkAlice, mallory);

      final alicePayload = QrVerificationPayload(
        myPublicKey: pkAlice,
        theirPublicKey: pkBob,
        expectedSafetyNumber: realNumber,
      );
      final mitmPayload = QrVerificationPayload(
        myPublicKey: pkAlice,
        theirPublicKey: mallory,
        expectedSafetyNumber: mitm,
      );

      expect(alicePayload.verify(mitmPayload), isFalse);
    });

    test('QrVerificationPayload.version is 1', () {
      expect(QrVerificationPayload.version, equals(1));
    });

    test('QrSafetyNumberMismatch is an Exception', () {
      const e = QrSafetyNumberMismatch();
      expect(e, isA<Exception>());
      expect(e.toString(), contains('MITM'));
    });

    test('verify() is symmetric', () {
      final number = SafetyNumbers.compute(pkAlice, pkBob);
      final p1 = QrVerificationPayload(
        myPublicKey: pkAlice,
        theirPublicKey: pkBob,
        expectedSafetyNumber: number,
      );
      final p2 = QrVerificationPayload(
        myPublicKey: pkBob,
        theirPublicKey: pkAlice,
        expectedSafetyNumber: number,
      );
      expect(p1.verify(p2), equals(p2.verify(p1)));
    });
  });
}
