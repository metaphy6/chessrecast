import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('Argon2id — floor enforcement (§2.2)', () {
    test('floor params succeed (m=16384 KiB, t=4)', () {
      expect(
        () => Argon2idStub.derive(
          password: RecoveryCode.generate().entropy,
          salt: 'salt'.codeUnits,
          mKib: Argon2idStub.mMinKib,
          iterations: Argon2idStub.tMin,
        ),
        returnsNormally,
      );
    });

    test('m below floor throws KdfParamsTooWeakError', () {
      expect(
        () => Argon2idStub.derive(
          password: RecoveryCode.generate().entropy,
          salt: 'salt'.codeUnits,
          mKib: Argon2idStub.mMinKib - 1,
          iterations: Argon2idStub.tMin,
        ),
        throwsA(isA<KdfParamsTooWeakError>()),
      );
    });

    test('t below floor throws KdfParamsTooWeakError', () {
      expect(
        () => Argon2idStub.derive(
          password: RecoveryCode.generate().entropy,
          salt: 'salt'.codeUnits,
          mKib: Argon2idStub.mMinKib,
          iterations: Argon2idStub.tMin - 1,
        ),
        throwsA(isA<KdfParamsTooWeakError>()),
      );
    });

    test('mMinKib is 16384 (16 MiB)', () {
      expect(Argon2idStub.mMinKib, equals(16 * 1024));
    });

    test('tMin is 4', () {
      expect(Argon2idStub.tMin, equals(4));
    });

    test('KdfParamsTooWeakError includes param values in message', () {
      try {
        Argon2idStub.derive(
          password: RecoveryCode.generate().entropy,
          salt: 'salt'.codeUnits,
          mKib: 1024,
          iterations: 2,
        );
        fail('Expected KdfParamsTooWeakError');
      } on KdfParamsTooWeakError catch (e) {
        expect(e.toString(), contains('1024'));
        expect(e.toString(), contains('2'));
      }
    });
  });
}
