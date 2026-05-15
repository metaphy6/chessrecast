import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

void main() {
  group('Argon2id — adaptive parameters (§2.2)', () {
    test('derive returns 32-byte output at floor params', () {
      final result = Argon2idStub.derive(
        password: RecoveryCode.generate().entropy,
        salt: 'test-salt'.codeUnits,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(result.length, equals(32));
    });

    test('derive is deterministic for same inputs', () {
      final code = RecoveryCode.generate();
      final salt = 'chessrecast-v1'.codeUnits;
      final r1 = Argon2idStub.derive(
        password: code.entropy,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final r2 = Argon2idStub.derive(
        password: code.entropy,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(r1, equals(r2));
    });

    test('different passwords produce different outputs', () {
      final c1 = RecoveryCode.generate();
      final c2 = RecoveryCode.generate();
      final salt = 'test'.codeUnits;
      final r1 = Argon2idStub.derive(
        password: c1.entropy,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final r2 = Argon2idStub.derive(
        password: c2.entropy,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(r1, isNot(equals(r2)));
    });

    test('different salts produce different outputs', () {
      final code = RecoveryCode.generate();
      final r1 = Argon2idStub.derive(
        password: code.entropy,
        salt: 'salt-a'.codeUnits,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final r2 = Argon2idStub.derive(
        password: code.entropy,
        salt: 'salt-b'.codeUnits,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      expect(r1, isNot(equals(r2)));
    });

    test('higher iterations changes the output', () {
      final code = RecoveryCode.generate();
      final salt = 'salt'.codeUnits;
      final r1 = Argon2idStub.derive(
        password: code.entropy,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final r2 = Argon2idStub.derive(
        password: code.entropy,
        salt: salt,
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin + 1,
      );
      expect(r1, isNot(equals(r2)));
    });
  });
}
