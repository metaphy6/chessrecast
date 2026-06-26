# P2P Recovery Runbook — Phase 2 Acceptance Gate

**Version:** 1.0  
**Phase:** 2 — Identity, key management, and recovery  
**Status:** Draft (Phase 3 signaling server required for full production flow)

This runbook documents the end-to-end account recovery procedure for Chess Recast P2P.
It is the acceptance-gate document for Phase 2 §2.5.

---

## Prerequisites

- User has previously opted in to account recovery and confirmed "I have written down my 16 words"
- The wrapped backup blob is stored on the signaling server (uploaded at opt-in time)
- The user has their 16-word BIP-39 recovery phrase

---

## Recovery flow — step by step

### Step 1: Launch the app on a new device

Open Chess Recast. On the login screen, tap **"Restore account"**.

### Step 2: Enter recovery words

Enter the 16 BIP-39 words exactly as written down.

**Client-side validation (happens locally, before any network call):**

1. Each word is looked up in the BIP-39 wordlist.
   - Unknown word → red inline error "Word N not recognised". Do not proceed.
2. BIP-39 checksum is verified over all 16 words.
   - Checksum fail → red banner "One or more words may be incorrect — check spelling". Do not proceed.

This validation runs in < 100 ms and protects the user from waiting 1.5–4 s for Argon2id to run on bad input.

### Step 3: Fetch wrapped blob from signaling server

The app calls `GET /v1/accounts/recovery?account_pub=<fingerprint>`.

- **Server offline / 503** → display "Recovery temporarily unavailable — try again in a few minutes." Do NOT ask the user to re-enter their words.
- **404 Not Found** → display "No recovery backup found for this account. Recovery is not possible."
- **200 OK** → continue to Step 4.

### Step 4: Derive KEK and unwrap account key

The app runs Argon2id with the params stored in the blob header (m, t, p, salt).

- Show a progress spinner: "Verifying your recovery code…"
- On `KdfParamsTooWeakError`: this should never happen (server enforces floor). If it does, display "Backup blob is corrupted — contact support."
- On `BlobIntegrityError`: the recovery code is wrong or the blob is corrupted.  
  Display: "Recovery code doesn't match. Check each word and try again."  
  **Do not** indicate which words are wrong (prevents oracle attacks).

### Step 5: Generate fresh device key

After successful unwrap, the app calls `DeviceIdentity.generate()` to create a new Ed25519 keypair for this device.

### Step 6: Rebind on the signaling server

The app calls `POST /v1/accounts/rebind` with:
```json
{
  "account_pub": "<recovered account pubkey>",
  "new_device_pub": "<new device pubkey>",
  "account_sig": "<Ed25519 sig of rebind payload under recovered account key>",
  "attestation": "<Play Integrity / DeviceCheck token>"
}
```

**Server responses:**
- `200 OK` → recovery complete. Proceed to Step 7.
- `409 REBIND_RACE_LOST` → another device won the race. Display "Recovery was already completed on another device. If you didn't do this, your account may be compromised — change your recovery code immediately."
- `503` → display "Rebind temporarily unavailable — try again in a few minutes."

### Step 7: Persist new device key

The new Ed25519 keypair is stored in platform secure storage (iOS Keychain / Android Keystore / Linux libsecret + fallback).

Show "Account restored successfully!" and proceed to the main screen.

---

## Scenario: old device returns after rebind

If the old device comes back online and attempts to sign a frame with its now-replaced device key:

1. The signaling server rejects the signature (unknown device key).
2. The app on the old device receives `DEVICE_REPLACED` error.
3. UI surfaces: "This device has been replaced by a recovery operation. Your game history is preserved locally but you cannot start new games until you register this device again."

---

## Scenario: re-wrap on KDF upgrade

When the user unlocks the app on any device and the stored blob's `kdf_version` is below the current floor:

1. App displays a one-line toast: "Upgrading account security — this takes a few seconds."
2. App re-derives KEK at the new (higher) params.
3. App re-wraps the account key and uploads a fresh blob to the server (signed with the device key).
4. Toast dismisses automatically after upload confirmation.

The user never needs to re-enter their recovery words for this upgrade.

---

## Supported platforms

| Platform | Secure storage | Recovery supported |
|---|---|---|
| iOS | Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) | ✅ Full |
| Android | Keystore (StrongBox preferred) | ✅ Full |
| macOS | Keychain | ✅ Full |
| Windows | DPAPI/NCRYPT | ✅ Full |
| Linux | libsecret + Argon2id-wrapped fallback | ✅ Full |
| Web | WebCrypto Ed25519 (non-extractable) | ⚠️ Reduced (key cannot be exported; no cloud backup) |

---

## Proof tests

All Phase 2 proof tests must be green before this runbook is considered final:

- `frontend/test/p2p/identity/recovery_code_entropy_test.dart`
- `frontend/test/p2p/identity/recovery_code_bip39_checksum_test.dart`
- `frontend/test/p2p/identity/argon2_adaptive_test.dart`
- `frontend/test/p2p/identity/argon2_floor_enforced_test.dart`
- `frontend/test/p2p/identity/kdf_version_upgrade_test.dart`
- `frontend/test/p2p/identity/recovery_flow_test.dart`
- `frontend/test/p2p/identity/auto_rewrap_on_upgrade_test.dart`
- `frontend/test/p2p/identity/account_migration_chaos_test.dart`
- `frontend/test/p2p/identity/recovery_cross_platform_kat_test.dart`
- `signaling/internal/recovery/recovery_test.go` (full, once Phase 3 lands)
- `signaling/internal/rebind/rebind_test.go` (full, once Phase 3 lands)

---

*This document is updated automatically when Phase 3 ships the real signaling server. Until then, Steps 3 and 6 are stubs.*
