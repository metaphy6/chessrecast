/// AES-256-GCM at-rest encryption for the saved-games DB payload column.
///
/// The cipher is keyed by a per-install 256-bit random key (`kek`).
/// The key material is stored as base64 in the SQLite `meta` table under
/// `kdf_params` (Phase 2.1 will move it to OS secure storage when device
/// identity is available; the meta-table slot is kept as a migration target).
///
/// Ciphertext format (stored as base64url in the `payload` column):
///   [nonce: 12 bytes] || [ciphertext + GCM tag]
///
/// The GCM tag is appended to the ciphertext by the `encrypt` package.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// Symmetric cipher for at-rest encryption of saved-game JSON payloads.
///
/// One instance is created per [SavedGamesLocalEncrypted] session; the
/// underlying key never leaves the process except through [exportKeyBase64]
/// (which is only called to persist it to the `meta` table on first run).
class AtRestCipher {
  static const int cipherVersion = 1;
  static const int _keyBytes = 32; // 256 bits
  static const int _nonceBytes = 12; // 96 bits (GCM recommended)

  final Key _key;

  AtRestCipher._(this._key);

  /// Generate a new random key (first-time database setup).
  factory AtRestCipher.generate() {
    final rng = Random.secure();
    final keyBytes = Uint8List.fromList(
      List.generate(_keyBytes, (_) => rng.nextInt(256)),
    );
    return AtRestCipher._(Key(keyBytes));
  }

  /// Restore from a base64-encoded key stored in the `meta` table.
  ///
  /// Throws [FormatException] if [b64] does not decode to exactly [_keyBytes]
  /// bytes — this allows callers to detect a corrupt or tampered `kdf_params`
  /// row rather than silently producing an unusable cipher.
  factory AtRestCipher.fromBase64(String b64) {
    final decoded = base64.decode(b64);
    if (decoded.length != _keyBytes) {
      throw FormatException(
        'Invalid KEK: expected $_keyBytes bytes, got ${decoded.length}',
      );
    }
    return AtRestCipher._(Key(decoded));
  }

  /// Export the key as base64 for storage in the `meta` table.
  String exportKeyBase64() => base64.encode(_key.bytes);

  /// Encrypt a plaintext JSON [payload].
  ///
  /// Returns a base64url-encoded blob: 12-byte nonce followed by the AES-GCM
  /// ciphertext (which already includes the 16-byte authentication tag).
  String encryptPayload(String payload) {
    final rng = Random.secure();
    final iv = IV(
      Uint8List.fromList(List.generate(_nonceBytes, (_) => rng.nextInt(256))),
    );
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(payload, iv: iv);

    // Prepend nonce to ciphertext so the receiver can extract it.
    final combined = Uint8List(_nonceBytes + encrypted.bytes.length);
    combined.setRange(0, _nonceBytes, iv.bytes);
    combined.setRange(_nonceBytes, combined.length, encrypted.bytes);
    return base64Url.encode(combined);
  }

  /// Decrypt a [ciphertext] blob produced by [encryptPayload].
  ///
  /// Throws [FormatException] / [ArgumentError] if the ciphertext is truncated
  /// or the GCM authentication tag fails (tampered data).
  String decryptPayload(String ciphertext) {
    final combined = base64Url.decode(ciphertext);
    if (combined.length <= _nonceBytes) {
      throw const FormatException('at_rest_cipher: ciphertext too short');
    }
    final iv = IV(Uint8List.fromList(combined.sublist(0, _nonceBytes)));
    final encryptedBytes = Encrypted(combined.sublist(_nonceBytes));
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    return encrypter.decrypt(encryptedBytes, iv: iv);
  }
}
