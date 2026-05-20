// T-D-001 §9.4 — Private keys are stored in hardware-backed Keystore /
// Secure Enclave when available.
//
// Proof: SecureStoragePolicy enforces StorageTier.tee as the minimum
// production tier, and correctly classifies hardware vs software tiers.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/identity/secure_storage_policy.dart';

void main() {
  group('T-D-001 §9.4 — Hardware-backed key storage policy', () {
    test('StorageTier is ordered software < osKeychain < tee < secureElement', () {
      expect(StorageTier.software.index,
          lessThan(StorageTier.osKeychain.index));
      expect(StorageTier.osKeychain.index, lessThan(StorageTier.tee.index));
      expect(StorageTier.tee.index,
          lessThan(StorageTier.secureElement.index));
    });

    test('minimum production tier is StorageTier.tee', () {
      expect(SecureStoragePolicy.kMinProductionTier, equals(StorageTier.tee));
    });

    test('tee tier meets production requirement', () {
      expect(
        SecureStoragePolicy.meetsProductionRequirement(StorageTier.tee),
        isTrue,
      );
    });

    test('secureElement tier meets production requirement', () {
      expect(
        SecureStoragePolicy.meetsProductionRequirement(
            StorageTier.secureElement),
        isTrue,
      );
    });

    test('software tier does NOT meet production requirement', () {
      expect(
        SecureStoragePolicy.meetsProductionRequirement(StorageTier.software),
        isFalse,
        reason:
            'Keys in software storage have no hardware protection — must warn',
      );
    });

    test('osKeychain tier does NOT meet production requirement', () {
      expect(
        SecureStoragePolicy.meetsProductionRequirement(StorageTier.osKeychain),
        isFalse,
      );
    });

    test('isHardwareBacked returns true for tee and above', () {
      expect(SecureStoragePolicy.isHardwareBacked(StorageTier.tee), isTrue);
      expect(
          SecureStoragePolicy.isHardwareBacked(StorageTier.secureElement),
          isTrue);
    });

    test('isHardwareBacked returns false for software and osKeychain', () {
      expect(
          SecureStoragePolicy.isHardwareBacked(StorageTier.software), isFalse);
      expect(
          SecureStoragePolicy.isHardwareBacked(StorageTier.osKeychain),
          isFalse);
    });

    test('software fallback result includes a warning message', () {
      const result = KeyStorageResult.softwareFallback();
      expect(result.success, isTrue);
      expect(result.warningMessage, isNotNull);
      expect(result.warningMessage, isNotEmpty);
      expect(result.tier, equals(StorageTier.software));
    });

    test('hardware-backed result has no warning message', () {
      const result = KeyStorageResult.hardwareBacked(StorageTier.tee);
      expect(result.success, isTrue);
      expect(result.warningMessage, isNull);
    });

    test('test tier constant is software (CI-safe)', () {
      expect(SecureStoragePolicy.kTestTier, equals(StorageTier.software));
    });
  });
}
