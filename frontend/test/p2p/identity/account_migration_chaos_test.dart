import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/p2p/identity/identity.dart';

/// Account migration chaos scenarios (§2.2).
///
/// These tests verify the Dart-side behavioral contracts for migration.
/// Server-side atomicity (single-rebind race) is verified by
/// signaling/internal/rebind/rebind_test.go.
void main() {
  group('Account migration chaos (§2.2)', () {
    test('(a) old device still online — recovered key matches original', () {
      // Both "old device" and "new device" use the same recovery code.
      final accountKey = Uint8List(32)..fillRange(0, 32, 0x11);
      final code = RecoveryCode.generate();
      final kek = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final aad = Uint8List(4)..fillRange(0, 4, 0xA1);
      final blob = WrappedBlob.wrap(accountKey: accountKey, kek: kek, aad: aad);

      // "New device" enters the same words and recovers successfully
      final newCode = RecoveryCode.fromWords(code.words);
      final newKek = newCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final recovered = blob.unwrap(kek: newKek, aad: aad);
      expect(recovered, equals(accountKey));
    });

    test('(b) old device offline — recovery code still works', () {
      // The offline device scenario is identical from the Dart perspective:
      // user enters words → KEK derived → blob unwrapped.
      final accountKey = Uint8List(32)..fillRange(0, 32, 0x22);
      final code = RecoveryCode.generate();
      final kek = code.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final aad = Uint8List(4)..fillRange(0, 4, 0xB2);
      final wrapped = WrappedBlob.wrap(
        accountKey: accountKey,
        kek: kek,
        aad: aad,
      ).encode();
      final decoded = WrappedBlob.decode(wrapped);
      final recovered = decoded.unwrap(kek: kek, aad: aad);
      expect(recovered, equals(accountKey));
    });

    test(
      '(c) old device returning after rebind — key differs from new device',
      () {
        // After rebind, the new device generates a fresh device keypair.
        // The old device cannot present the same device key as valid after rebind.
        // This verifies that generating a new device key after recovery differs
        // from the old device key (different random generation).
        final oldDevice = DeviceIdentity.generate();
        final newDevice = DeviceIdentity.generate();
        // Keys are different — "self-quarantine" would be triggered by mismatch
        expect(oldDevice.publicKey, isNot(equals(newDevice.publicKey)));
      },
    );

    test(
      '(d) two new devices race — same recovery code, different device keys',
      () {
        // Both devices recover the same account key (from the blob)
        // but each generates a DIFFERENT device keypair.
        // Server enforces single-rebind atomically (Go-side);
        // Dart-side: both are valid from the recovery perspective.
        final code = RecoveryCode.generate();
        final kek = code.deriveKek(
          mKib: Argon2idStub.mMinKib,
          iterations: Argon2idStub.tMin,
        );
        final accountKey = Uint8List(32)..fillRange(0, 32, 0x33);
        final aad = Uint8List(4)..fillRange(0, 4, 0xD4);
        final blob = WrappedBlob.wrap(
          accountKey: accountKey,
          kek: kek,
          aad: aad,
        );

        final raceDeviceA = DeviceIdentity.generate();
        final raceDeviceB = DeviceIdentity.generate();

        // Both can unwrap the blob
        final recovA = blob.unwrap(kek: kek, aad: aad);
        final recovB = blob.unwrap(kek: kek, aad: aad);
        expect(recovA, equals(accountKey));
        expect(recovB, equals(accountKey));

        // But they have different device keys (server picks winner via REBIND_RACE_LOST)
        expect(raceDeviceA.publicKey, isNot(equals(raceDeviceB.publicKey)));
      },
    );

    test('(e) server read-only mode — wrong KEK produces typed error (not silent)', () {
      // When server is in read-only mode the client cannot upload a fresh blob.
      // On the Dart side, attempting to unwrap with a wrong code must produce a
      // BlobIntegrityError — never silent garbage — so the client can surface
      // "try again in a few minutes" specifically for bad-code vs server-unavailable.
      final accountKey = Uint8List(32)..fillRange(0, 32, 0x44);
      final realCode = RecoveryCode.generate();
      final kek = realCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      final aad = Uint8List(4)..fillRange(0, 4, 0xE5);
      final blob = WrappedBlob.wrap(accountKey: accountKey, kek: kek, aad: aad);

      final wrongCode = RecoveryCode.generate();
      final wrongKek = wrongCode.deriveKek(
        mKib: Argon2idStub.mMinKib,
        iterations: Argon2idStub.tMin,
      );
      // Must throw a typed error so caller can distinguish bad-code from server error
      expect(
        () => blob.unwrap(kek: wrongKek, aad: aad),
        throwsA(isA<BlobIntegrityError>()),
        reason:
            'Wrong recovery code must produce BlobIntegrityError, not silent null',
      );
    });
  });
}
