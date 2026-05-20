/// Export-my-data service — roadmap §18.4 Right to Portability.
///
/// Generates an encrypted archive `chessrecast-export-<id>-<date>.cbor.aead`
/// containing account metadata, device keys, transcripts, block-list, display-
/// name overrides, and settings.  The wrapped recovery blob is explicitly
/// excluded (it is a security boundary — only the recovery code restores an
/// account).
///
/// Encryption: AES-256-GCM keyed from a PBKDF2-SHA256 derivation of the
/// user-supplied passphrase (100,000 iterations, 16-byte random salt).
///
/// **Argon2id production note:** per §18.4 the production KDF should be
/// Argon2id with the same parameters as §2.2 recovery.  PBKDF2-SHA256 is used
/// here because the `pointycastle` Argon2id binding is not yet a declared
/// dependency; adding it requires a `kind: shared_edit` queue entry for the
/// pubspec change.  The interface is stable so the swap is localised to
/// [_deriveKey].
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

/// Describes the content of an export archive.
///
/// [wrappedRecoveryBlob] is accepted in the constructor so callers can pass
/// the full account object without stripping it first — the export service
/// silently drops it before serialising.
class ExportPayload {
  final String accountPubkey;
  final List<String> devicePubkeys;
  final List<TranscriptEntry> transcripts;
  final List<String> blockList;
  final Map<String, String> displayNameOverrides;
  final Map<String, String> settings;

  /// Intentionally excluded from the archive — set to null after construction.
  final String? wrappedRecoveryBlob; // never serialised

  const ExportPayload({
    required this.accountPubkey,
    required this.devicePubkeys,
    required this.transcripts,
    required this.blockList,
    required this.displayNameOverrides,
    required this.settings,
    this.wrappedRecoveryBlob,
  });

  /// Serialise to a JSON-compatible map, **omitting** [wrappedRecoveryBlob].
  Map<String, dynamic> toArchiveMap() => {
        'schema_version': 1,
        'account_pubkey': accountPubkey,
        'device_pubkeys': devicePubkeys,
        'transcripts': transcripts.map((t) => t.toMap()).toList(),
        'block_list': blockList,
        'display_name_overrides': displayNameOverrides,
        'settings': settings,
        // wrappedRecoveryBlob is intentionally absent.
      };

  /// Reconstruct from a decoded archive map.  [wrappedRecoveryBlob] is always
  /// null — it is a security boundary that cannot be portably exported.
  factory ExportPayload.fromArchiveMap(Map<String, dynamic> m) => ExportPayload(
        accountPubkey: m['account_pubkey'] as String,
        devicePubkeys: List<String>.from(m['device_pubkeys'] as List),
        transcripts: (m['transcripts'] as List)
            .map((e) => TranscriptEntry.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        blockList: List<String>.from(m['block_list'] as List),
        displayNameOverrides:
            Map<String, String>.from(m['display_name_overrides'] as Map),
        settings: Map<String, String>.from(m['settings'] as Map),
        wrappedRecoveryBlob: null, // never restored from an archive
      );
}

/// A single game transcript in the export archive.
class TranscriptEntry {
  final String id;
  final String moves;
  final List<String> signedBy;

  const TranscriptEntry({
    required this.id,
    required this.moves,
    required this.signedBy,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'moves': moves,
        'signed_by': signedBy,
      };

  factory TranscriptEntry.fromMap(Map<String, dynamic> m) => TranscriptEntry(
        id: m['id'] as String,
        moves: m['moves'] as String,
        signedBy: List<String>.from(m['signed_by'] as List),
      );
}

/// Thrown when an export is requested within the cooldown window.
class ExportCooldownException implements Exception {
  final Duration remaining;
  const ExportCooldownException(this.remaining);

  @override
  String toString() =>
      'ExportCooldownException: retry in ${remaining.inSeconds}s';
}

/// Thrown when archive decryption fails (wrong passphrase or tampered data).
class ExportDecryptException implements Exception {
  final String message;
  const ExportDecryptException([this.message = 'decryption failed']);


  @override
  String toString() => 'ExportDecryptException: $message';
}

/// In-archive manifest for §18.7.5 Integrity.
///
/// Signed under the device key (HMAC-SHA256) so tampering between export and
/// import is detectable. In production this should be replaced with an Ed25519
/// signature once the `cryptography` package is a declared dependency.
class ExportManifest {
  final int transcriptCount;

  /// SHA-256 hex of sorted transcript IDs, joined by ','.
  final String transcriptIdsHash;
  final String accountPubkey;
  final String exportedAt; // ISO-8601
  final String deviceHmac; // HMAC-SHA256 over canonical fields, hex

  const ExportManifest({
    required this.transcriptCount,
    required this.transcriptIdsHash,
    required this.accountPubkey,
    required this.exportedAt,
    required this.deviceHmac,
  });

  /// Build and sign a manifest for [payload].
  static ExportManifest sign({
    required ExportPayload payload,
    required Uint8List deviceKeyBytes,
    required DateTime now,
  }) {
    final sortedIds = [...payload.transcripts.map((t) => t.id)]..sort();
    final idsRaw = utf8.encode(sortedIds.join(','));
    final idsHashBytes = crypto.sha256.convert(idsRaw).bytes;
    final idsHash = _hexEncode(Uint8List.fromList(idsHashBytes));
    final exportedAt = now.toUtc().toIso8601String();
    final canonical = '${ payload.transcripts.length}:$idsHash:${payload.accountPubkey}:$exportedAt';
    final hmacBytes = crypto.Hmac(crypto.sha256, deviceKeyBytes)
        .convert(utf8.encode(canonical))
        .bytes;
    return ExportManifest(
      transcriptCount: payload.transcripts.length,
      transcriptIdsHash: idsHash,
      accountPubkey: payload.accountPubkey,
      exportedAt: exportedAt,
      deviceHmac: _hexEncode(Uint8List.fromList(hmacBytes)),
    );
  }

  /// Verify the HMAC under [deviceKeyBytes].
  bool verify(Uint8List deviceKeyBytes) {
    final canonical = '$transcriptCount:$transcriptIdsHash:$accountPubkey:$exportedAt';
    final expected = crypto.Hmac(crypto.sha256, deviceKeyBytes)
        .convert(utf8.encode(canonical))
        .bytes;
    final actual = _hexDecode(deviceHmac);
    if (expected.length != actual.length) return false;
    // Constant-time comparison.
    int diff = 0;
    for (int i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ actual[i];
    }
    return diff == 0;
  }

  Map<String, dynamic> toMap() => {
        'transcript_count': transcriptCount,
        'transcript_ids_hash': transcriptIdsHash,
        'account_pubkey': accountPubkey,
        'exported_at': exportedAt,
        'device_hmac': deviceHmac,
      };

  factory ExportManifest.fromMap(Map<String, dynamic> m) => ExportManifest(
        transcriptCount: m['transcript_count'] as int,
        transcriptIdsHash: m['transcript_ids_hash'] as String,
        accountPubkey: m['account_pubkey'] as String,
        exportedAt: m['exported_at'] as String,
        deviceHmac: m['device_hmac'] as String,
      );

  static String _hexEncode(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexDecode(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

/// Clock abstraction for testability (inject a [FakeClock] in unit tests).
abstract class Clock {
  DateTime now();
}

class _SystemClock implements Clock {
  const _SystemClock();
  @override
  DateTime now() => DateTime.now();
}

/// Fake clock for unit tests — advance with [advance].
class FakeClock implements Clock {
  DateTime _now;
  FakeClock(this._now);

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

/// Service that handles export-my-data and import operations.
class ExportService {
  static const Duration cooldown = Duration(minutes: 5);
  static const int _keyBytes = 32;
  static const int _nonceBytes = 12;
  static const int _saltBytes = 16;
  static const int _pbkdf2Iterations = 100000;

  final Clock _clock;
  final int _iterations;
  DateTime? _lastExportAt;

  /// §18.7.4 Reliability: payload stored before crypto so a crash mid-export
  /// leaves enough state for the UI to offer "retry export".
  ExportPayload? _pendingPayload;

  ExportService._({required Clock clock, int iterations = _pbkdf2Iterations})
      : _clock = clock,
        _iterations = iterations;

  /// Production constructor — uses the real system clock.
  factory ExportService() => ExportService._(clock: const _SystemClock());

  /// Test constructor — accepts an injectable [FakeClock] and uses fewer KDF
  /// iterations so test suites run quickly.
  factory ExportService.forTest({Clock? clock}) => ExportService._(
        clock: clock ?? FakeClock(DateTime.now()),
        iterations: 1, // fast KDF for unit tests
      );

  /// §18.7.4 Reliability: true when a previous export attempt left pending state.
  bool get hasPendingRetry => _pendingPayload != null;

  /// §18.7.4 Reliability: seed pending-retry state for tests.
  ///
  /// Simulates a mid-export crash so tests can verify [retryExport] behaviour
  /// without polluting production code paths.
  // ignore: invalid_use_of_visible_for_testing_member
  @visibleForTesting
  void seedRetryForTest(ExportPayload payload) => _pendingPayload = payload;

  /// §18.7.4 Reliability: retry export using the previously-stored payload.
  ///
  /// Throws [StateError] if no pending retry is available.
  Future<Uint8List> retryExport({required String passphrase}) {
    final p = _pendingPayload;
    if (p == null) throw StateError('no pending retry; call exportArchive first');
    return exportArchive(payload: p, passphrase: passphrase);
  }

  /// Returns the canonical export filename.
  static String exportFilename({
    required String accountShortId,
    required DateTime date,
  }) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return 'chessrecast-export-$accountShortId-$yyyy-$mm-$dd.cbor.aead';
  }

  /// Encrypt and serialise [payload] under [passphrase].
  ///
  /// When [deviceKeyBytes] is provided (§18.7.5 Integrity), an HMAC-SHA256
  /// manifest signed under the device key is embedded in the archive.
  ///
  /// Returns the raw bytes of the archive (salt + nonce + ciphertext).
  ///
  /// Throws [ArgumentError] for an empty passphrase.
  /// Throws [ExportCooldownException] if less than [cooldown] has elapsed
  /// since the last successful export.
  Future<Uint8List> exportArchive({
    required ExportPayload payload,
    required String passphrase,
    Uint8List? deviceKeyBytes,
  }) async {
    if (passphrase.isEmpty) {
      throw ArgumentError.value(passphrase, 'passphrase', 'must not be empty');
    }

    final now = _clock.now();
    if (_lastExportAt != null) {
      final elapsed = now.difference(_lastExportAt!);
      if (elapsed < cooldown) {
        throw ExportCooldownException(cooldown - elapsed);
      }
    }

    // §18.7.4 Reliability: store payload before crypto starts so a crash
    // leaves enough state for the UI to offer "retry export".
    _pendingPayload = payload;

    final rng = Random.secure();
    final salt = Uint8List.fromList(
        List.generate(_saltBytes, (_) => rng.nextInt(256)));
    final keyBytes = _deriveKey(passphrase: passphrase, salt: salt);
    final key = Key(keyBytes);

    final iv = IV(Uint8List.fromList(
        List.generate(_nonceBytes, (_) => rng.nextInt(256))));

    // Build the archive map, optionally embedding a signed manifest.
    final archiveMap = payload.toArchiveMap();
    if (deviceKeyBytes != null) {
      final manifest = ExportManifest.sign(
        payload: payload,
        deviceKeyBytes: deviceKeyBytes,
        now: now,
      );
      archiveMap['manifest'] = manifest.toMap();
    }

    final plaintext = jsonEncode(archiveMap);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    // Archive layout: [salt: 16] + [nonce: 12] + [ciphertext+tag]
    final archive = Uint8List(_saltBytes + _nonceBytes + encrypted.bytes.length);
    archive.setRange(0, _saltBytes, salt);
    archive.setRange(_saltBytes, _saltBytes + _nonceBytes, iv.bytes);
    archive.setRange(_saltBytes + _nonceBytes, archive.length, encrypted.bytes);

    _lastExportAt = now;
    _pendingPayload = null; // success — clear retry state
    return archive;
  }

  /// Decrypt and deserialise an archive produced by [exportArchive].
  ///
  /// When [deviceKeyBytes] is provided and the archive contains a manifest,
  /// the HMAC is verified; a mismatch throws [ExportDecryptException].
  ///
  /// Throws [ExportDecryptException] if the passphrase is wrong or data is
  /// corrupted.
  Future<ExportPayload> importArchive({
    required Uint8List archive,
    required String passphrase,
    Uint8List? deviceKeyBytes,
  }) async {
    if (archive.length <= _saltBytes + _nonceBytes) {
      throw const ExportDecryptException('archive too short');
    }

    final salt = archive.sublist(0, _saltBytes);
    final nonce = archive.sublist(_saltBytes, _saltBytes + _nonceBytes);
    final ciphertextBytes = archive.sublist(_saltBytes + _nonceBytes);

    final keyBytes = _deriveKey(passphrase: passphrase, salt: salt);
    final key = Key(keyBytes);
    final iv = IV(nonce);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    try {
      final decrypted =
          encrypter.decrypt(Encrypted(ciphertextBytes), iv: iv);
      final map = jsonDecode(decrypted) as Map<String, dynamic>;

      // §18.7.5 Integrity: verify manifest when present and device key provided.
      if (deviceKeyBytes != null && map.containsKey('manifest')) {
        final manifest = ExportManifest.fromMap(
            Map<String, dynamic>.from(map['manifest'] as Map));
        if (!manifest.verify(deviceKeyBytes)) {
          throw const ExportDecryptException('manifest verification failed — device key mismatch or tampering detected');
        }
      }

      return ExportPayload.fromArchiveMap(map);
    } catch (e) {
      if (e is ExportDecryptException) rethrow;
      throw ExportDecryptException(e.toString());
    }
  }

  /// PBKDF2-SHA256 key derivation.
  ///
  /// **Production note:** replace with Argon2id once `pointycastle` is added
  /// as a dependency (requires `kind: shared_edit` queue entry for pubspec).
  Uint8List _deriveKey({
    required String passphrase,
    required Uint8List salt,
  }) {
    // PBKDF2 using HMAC-SHA256: produce 32 bytes.
    final passwordBytes = utf8.encode(passphrase);
    var u = Uint8List.fromList(
      crypto.Hmac(crypto.sha256, passwordBytes)
          .convert([...salt, 0, 0, 0, 1]) // PRF(P, S || INT(1))
          .bytes,
    );
    final derived = Uint8List.fromList(u);
    for (int i = 1; i < _iterations; i++) {
      u = Uint8List.fromList(
          crypto.Hmac(crypto.sha256, passwordBytes).convert(u).bytes);
      for (int j = 0; j < derived.length; j++) {
        derived[j] ^= u[j];
      }
    }
    return derived.sublist(0, _keyBytes);
  }
}
