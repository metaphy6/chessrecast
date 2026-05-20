// §9.4 T-D-001 — Private keys stored in hardware-backed Keystore / Secure Enclave.
//
// The platform storage layer must declare whether it offers hardware-backed
// protection.  The policy enforced here is:
//   - On Android: use Keystore hardware-backed key store (StrongBox or TEE).
//   - On iOS/macOS: use Secure Enclave (when available) or Data Protection.
//   - On Linux/Windows (desktop): use platform credential store (keychain /
//     DPAPI / libsecret) — hardware attestation not available.
//   - Pure Dart test / CI: StorageTier.software (acceptable in test only).
//
// Production code checks StorageTier ≥ StorageTier.tee before writing a key;
// if the device cannot provide TEE-level storage, it surfaces a warning (not
// a hard error) and falls back to software-encrypted storage.
library;

/// Tiers of hardware security for key storage, ordered from weakest to strongest.
enum StorageTier {
  /// Pure software (unit tests, CI, desktop fallback).
  software,

  /// OS-level credential store (e.g., DPAPI, libsecret, macOS Keychain without
  /// Secure Enclave).
  osKeychain,

  /// Trusted Execution Environment (Android Keystore TEE, iOS Data Protection).
  tee,

  /// Dedicated Secure Element / StrongBox / Apple T2 / Secure Enclave.
  secureElement,
}

/// Policy constants for device-identity key storage (§9.4 / §2.1).
class SecureStoragePolicy {
  /// Minimum acceptable tier for production key storage.
  ///
  /// Keys stored below this tier trigger a user warning, but are still
  /// accepted (degraded security acknowledged in the UI).
  static const StorageTier kMinProductionTier = StorageTier.tee;

  /// Tier used in unit tests (to avoid requiring hardware in CI).
  static const StorageTier kTestTier = StorageTier.software;

  /// Return true when [actual] meets or exceeds the production requirement.
  static bool meetsProductionRequirement(StorageTier actual) =>
      actual.index >= kMinProductionTier.index;

  /// Return true when [actual] provides the strongest available protection.
  static bool isHardwareBacked(StorageTier actual) =>
      actual.index >= StorageTier.tee.index;
}

/// Result of a key-storage enrollment attempt.
class KeyStorageResult {
  final StorageTier tier;
  final bool success;
  final String? warningMessage;

  const KeyStorageResult({
    required this.tier,
    required this.success,
    this.warningMessage,
  });

  /// Convenience: successful hardware-backed storage.
  const KeyStorageResult.hardwareBacked(StorageTier tier)
      : this(tier: tier, success: true);

  /// Convenience: software-only fallback with a UI warning.
  const KeyStorageResult.softwareFallback()
      : this(
          tier: StorageTier.software,
          success: true,
          warningMessage:
              'Hardware-backed key storage is not available on this device. '
              'Keys are protected by software encryption only.',
        );
}
