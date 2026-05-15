import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('Key wipe atomicity (§2.4)', () {
    test('zeroize fills all 64 private key bytes with zeros', () {
      final id = DeviceIdentity.generate();
      // Confirm it is non-zero before zeroize
      expect(id.privateKey.any((b) => b != 0), isTrue);
      id.zeroize();
      for (int i = 0; i < id.privateKey.length; i++) {
        expect(
          id.privateKey[i],
          equals(0),
          reason: 'Byte $i should be zero after zeroize',
        );
      }
    });

    test('zeroize is idempotent — calling twice does not throw', () {
      final id = DeviceIdentity.generate();
      id.zeroize();
      id.zeroize(); // second call must not throw
    });

    test('public key is unaffected by zeroize', () {
      final id = DeviceIdentity.generate();
      final pubKeyCopy = Uint8List.fromList(id.publicKey);
      id.zeroize();
      // publicKey buffer itself is unchanged (zeroize only clears privateKey)
      expect(id.publicKey, equals(pubKeyCopy));
    });

    test('BiometricLockout wipe callback is called synchronously', () {
      bool called = false;
      final lockout = BiometricLockout(maxFailures: 1);
      lockout.recordFailure(
        onWipe: () {
          called = true;
        },
      );
      expect(called, isTrue);
    });
  });
}
