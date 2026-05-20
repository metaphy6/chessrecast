// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// ─── DeviceIdentity — Ed25519 key management (§2.1) ─────────────────────────

/// Represents an Ed25519 device keypair.
///
/// Production code MUST use libsodium FFI for constant-time guarantees.
/// This pure-Dart implementation is used in unit tests and on platforms
/// where libsodium FFI is unavailable (per roadmap §2.1: "[package:cryptography]
/// is the Dart fallback for unit tests").
///
/// Key layout (Ed25519 convention):
///   privateKey: 64 bytes = seed_32 || publicKey_32
///   publicKey:  32 bytes
class DeviceIdentity {
  final Uint8List publicKey;
  final Uint8List privateKey; // 64 bytes: seed(32) || pub(32)

  DeviceIdentity._({required this.publicKey, required this.privateKey});

  /// Generate a fresh Ed25519 keypair using a random 32-byte seed.
  factory DeviceIdentity.generate() {
    final seed = _randomBytes(32);
    return DeviceIdentity.fromSeed(seed);
  }

  /// Reconstruct a [DeviceIdentity] from a 32-byte seed.
  ///
  /// The public key is deterministically derived as SHA-256(seed || 0x01).
  factory DeviceIdentity.fromSeed(List<int> seed) {
    assert(seed.length == 32, 'Ed25519 seed must be 32 bytes');
    final seedBytes = Uint8List.fromList(seed);
    // Derive public key deterministically from seed.
    // Note: real Ed25519 uses curve-point multiplication; this stub uses
    // a SHA-256 PRF so tests can verify determinism without libsodium.
    final pubInput = Uint8List(33)
      ..setRange(0, 32, seedBytes)
      ..[32] = 0x01;
    final pubKey = Uint8List.fromList(sha256.convert(pubInput).bytes);
    final privKey = Uint8List(64)
      ..setRange(0, 32, seedBytes)
      ..setRange(32, 64, pubKey);
    return DeviceIdentity._(publicKey: pubKey, privateKey: privKey);
  }

  /// Sign [message] with this device's private key.
  ///
  /// Returns a 64-byte stub signature: HMAC-SHA256(publicKey, message) padded
  /// to 64 bytes.
  ///
  /// NOTE: production uses libsodium `crypto_sign_ed25519_detached` which
  /// requires the private key. This stub uses the public key as HMAC key so
  /// that [verify] can operate with only the public key — sufficient for
  /// behavioral contract tests.
  Uint8List sign(List<int> message) {
    final hmac = Hmac(sha256, publicKey);
    final h = hmac.convert(message).bytes;
    // Pad to 64 bytes (real Ed25519 signature is 64 bytes)
    final sig = Uint8List(64)..setRange(0, h.length, h);
    return sig;
  }

  /// Verify a signature produced by [sign].
  ///
  /// Returns true iff the first 32 bytes of [signature] match
  /// HMAC-SHA256(publicKey, message).
  static bool verify(
    Uint8List publicKey,
    List<int> message,
    List<int> signature,
  ) {
    if (signature.length != 64) return false;
    final hmac = Hmac(sha256, publicKey);
    final expected = hmac.convert(message).bytes;
    final sigBytes = Uint8List.fromList(signature);
    // Constant-time comparison of the first 32 bytes
    int diff = 0;
    for (int i = 0; i < 32; i++) {
      diff |= sigBytes[i] ^ expected[i];
    }
    return diff == 0;
  }

  /// Wipe private key material from memory.
  ///
  /// In production, this uses sodium_memzero; here we overwrite with zeros.
  void zeroize() {
    privateKey.fillRange(0, privateKey.length, 0);
  }
}

// ─── DeviceFingerprint — §2.1 ────────────────────────────────────────────────

/// Generates and formats the device fingerprint for display.
///
/// Format: lowercase Base32 of SHA-256(pubkey)[:10], grouped `xxxx-xxxx-xx`.
/// Surfaced in the UI as "Device ID".
class DeviceFingerprint {
  DeviceFingerprint._();

  static const _base32Chars = 'abcdefghijklmnopqrstuvwxyz234567';

  /// Compute the fingerprint for [publicKey].
  ///
  /// Returns a string like `"abcd-efgh-ij"` (10 base32 chars, 2 groups of 4
  /// and one group of 2, separated by hyphens).
  static String compute(Uint8List publicKey) {
    final digest = sha256.convert(publicKey).bytes;
    // Extract 10 base32 characters from the first 7 bytes (10 * 5 bits = 50 bits ≤ 56 bits)
    final chars = _toBase32(Uint8List.fromList(digest), 10);
    return '${chars.substring(0, 4)}-${chars.substring(4, 8)}-${chars.substring(8)}';
  }

  static String _toBase32(Uint8List bytes, int length) {
    final buf = StringBuffer();
    int bits = 0;
    int bitsInBuf = 0;
    int byteIdx = 0;
    while (buf.length < length) {
      if (bitsInBuf < 5) {
        bits = (bits << 8) | bytes[byteIdx++];
        bitsInBuf += 8;
      }
      bitsInBuf -= 5;
      buf.write(_base32Chars[(bits >> bitsInBuf) & 0x1F]);
    }
    return buf.toString();
  }
}

// ─── BiometricLockout — §2.1 ─────────────────────────────────────────────────

/// Tracks consecutive biometric/PIN auth failures and wipes the device key
/// after [maxFailures] consecutive failures.
class BiometricLockout {
  final int maxFailures;
  int _consecutiveFailures = 0;
  bool _wiped = false;

  BiometricLockout({this.maxFailures = 10});

  int get consecutiveFailures => _consecutiveFailures;
  bool get wiped => _wiped;

  /// Record a successful authentication; resets the failure counter.
  void recordSuccess() {
    _consecutiveFailures = 0;
  }

  /// Record a failed authentication.
  ///
  /// If [maxFailures] consecutive failures are reached, calls [onWipe] and
  /// marks the identity as wiped.
  void recordFailure({required void Function() onWipe}) {
    if (_wiped) return;
    _consecutiveFailures++;
    if (_consecutiveFailures >= maxFailures) {
      _wiped = true;
      onWipe();
    }
  }

  /// Reset the lockout state (used after account recovery).
  void reset() {
    _consecutiveFailures = 0;
    _wiped = false;
  }
}

// ─── SecureStorageBackend — §2.1 ─────────────────────────────────────────────

/// Abstract interface for platform-secure-storage.
///
/// Production implementations:
///   iOS   → Keychain (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
///   Android → Android Keystore (StrongBox preferred)
///   macOS → Keychain
///   Windows → DPAPI / NCRYPT
///   Linux → libsecret + Argon2id-wrapped on-disk file fallback
///
/// For unit tests, use [InMemorySecureStorage].
abstract class SecureStorageBackend {
  Future<void> write(String key, Uint8List value);
  Future<Uint8List?> read(String key);
  Future<void> delete(String key);
  Future<bool> containsKey(String key);
}

/// In-memory implementation of [SecureStorageBackend] for unit tests.
class InMemorySecureStorage implements SecureStorageBackend {
  final Map<String, Uint8List> _store = {};

  @override
  Future<void> write(String key, Uint8List value) async {
    _store[key] = Uint8List.fromList(value);
  }

  @override
  Future<Uint8List?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);
}

// ─── RecoveryCode — §2.2 ─────────────────────────────────────────────────────

/// BIP-39 style 16-word recovery code (165 bits entropy + 11-bit checksum).
///
/// The wordlist is a fixed 2048-word BIP-39 subset for reproducibility.
/// In production, the full BIP-39 wordlist is loaded from assets.
/// For tests, we use a minimal 2048-entry wordlist generated from SHA-256.
class RecoveryCode {
  static const int kWordCount = 16;
  static const int kEntropyBits = 165;

  final List<String> words;
  final Uint8List entropy; // 21 bytes (165 bits, zero-padded)

  RecoveryCode._({required this.words, required this.entropy});

  /// Generate a fresh random recovery code.
  ///
  /// Generates 21 bytes (168 bits); uses 165 bits of entropy + 11-bit BIP-39
  /// checksum derived from SHA-256.
  factory RecoveryCode.generate() {
    // Generate 21 bytes (168 bits) of random entropy.
    final rawEntropy = _randomBytes(21);
    // Zero the last 3 bits (we only use 165 bits).
    rawEntropy[20] = rawEntropy[20] & 0xF8;
    return RecoveryCode._fromEntropy(rawEntropy);
  }

  /// Reconstruct a [RecoveryCode] from a list of words.
  ///
  /// Verifies the BIP-39 checksum. Throws [Bip39ChecksumError] on failure.
  factory RecoveryCode.fromWords(List<String> words) {
    if (words.length != kWordCount) {
      throw ArgumentError('Expected $kWordCount words, got ${words.length}');
    }
    final wordlist = _wordlist();
    // Decode words to bits.
    final bits = <int>[];
    for (final word in words) {
      final idx = wordlist.indexOf(word);
      if (idx < 0) throw ArgumentError('Unknown BIP-39 word: $word');
      // Each word encodes 11 bits.
      for (int i = 10; i >= 0; i--) {
        bits.add((idx >> i) & 1);
      }
    }
    // 16 words × 11 bits = 176 bits total = 165 entropy + 11 checksum.
    final entropyBits = bits.sublist(0, 165);
    final checksumBits = bits.sublist(165, 176);
    // Pack entropy bits into bytes.
    final entropy = Uint8List(21);
    for (int i = 0; i < 165; i++) {
      if (entropyBits[i] == 1) {
        entropy[i >> 3] |= 1 << (7 - (i & 7));
      }
    }
    // Verify checksum: SHA-256(entropy_21_bytes)[0:11 bits]
    final hash = sha256.convert(entropy).bytes;
    for (int i = 0; i < 11; i++) {
      final expected = (hash[i >> 3] >> (7 - (i & 7))) & 1;
      if (checksumBits[i] != expected) {
        throw Bip39ChecksumError();
      }
    }
    return RecoveryCode._fromEntropy(entropy);
  }

  factory RecoveryCode._fromEntropy(Uint8List entropy) {
    final wordlist = _wordlist();
    // Append checksum bits.
    final hash = sha256.convert(entropy).bytes;
    // Build 176 bits: 165 entropy + 11 checksum.
    final bits = <int>[];
    for (int i = 0; i < 165; i++) {
      bits.add((entropy[i >> 3] >> (7 - (i & 7))) & 1);
    }
    for (int i = 0; i < 11; i++) {
      bits.add((hash[i >> 3] >> (7 - (i & 7))) & 1);
    }
    // Map every 11 bits to a word index.
    final words = <String>[];
    for (int w = 0; w < 16; w++) {
      int idx = 0;
      for (int b = 0; b < 11; b++) {
        idx = (idx << 1) | bits[w * 11 + b];
      }
      words.add(wordlist[idx]);
    }
    return RecoveryCode._(words: words, entropy: entropy);
  }

  /// Derive a 32-byte Key-Encryption-Key from the recovery-code entropy using
  /// the Argon2id stub (SHA-256 based for tests; production uses libsodium).
  Uint8List deriveKek({
    required int mKib,
    required int iterations,
    String salt = 'chessrecast-recovery-v1',
  }) {
    return Argon2idStub.derive(
      password: entropy,
      salt: utf8.encode(salt),
      mKib: mKib,
      iterations: iterations,
    );
  }

  @override
  String toString() => words.join(' ');

  // Minimal 2048-word BIP-39 wordlist (first word is always "abandon").
  // In tests, we need a consistent wordlist. We generate it deterministically.
  static List<String>? _cachedWordlist;
  static List<String> _wordlist() {
    _cachedWordlist ??= _generateMinimalWordlist();
    return _cachedWordlist!;
  }

  /// Returns the English BIP-39 wordlist used by [RecoveryCode].
  /// Exposed for [RecoveryWordlistLocalizer] and other callers that need the
  /// canonical English word list without instantiating a full [RecoveryCode].
  static List<String> generateWordlistForTest() => _wordlist();

  static List<String> _generateMinimalWordlist() {
    // Generate 2048 unique 4-8 letter words deterministically from SHA-256.
    // The first 2048 real BIP-39 words approximated by hash-derived slugs.
    // Real deployments use the actual BIP-39 English wordlist from assets.
    const realBip39Prefix = [
      'abandon',
      'ability',
      'able',
      'about',
      'above',
      'absent',
      'absorb',
      'abstract',
      'absurd',
      'abuse',
      'access',
      'accident',
      'account',
      'accuse',
      'achieve',
      'acid',
      'acoustic',
      'acquire',
      'across',
      'act',
      'action',
      'actor',
      'actress',
      'actual',
      'adapt',
      'add',
      'addict',
      'address',
      'adjust',
      'admit',
      'adult',
      'advance',
      'advice',
      'aerobic',
      'afford',
      'afraid',
      'again',
      'age',
      'agent',
      'agree',
      'ahead',
      'aim',
      'air',
      'airport',
      'aisle',
      'alarm',
      'album',
      'alcohol',
      'alert',
      'alien',
      'all',
      'alley',
      'allow',
      'almost',
      'alone',
      'alpha',
      'already',
      'also',
      'alter',
      'always',
      'amateur',
      'amazing',
      'among',
      'amount',
      'amused',
      'analyst',
      'anchor',
      'ancient',
      'anger',
      'angle',
      'angry',
      'animal',
      'ankle',
      'announce',
      'annual',
      'another',
      'answer',
      'antenna',
      'antique',
      'anxiety',
      'any',
      'apart',
      'apology',
      'appear',
      'apple',
      'approve',
      'april',
      'arch',
      'arctic',
      'area',
      'arena',
      'argue',
      'arm',
      'armed',
      'armor',
      'army',
      'around',
      'arrange',
      'arrest',
      'arrive',
      'arrow',
      'art',
      'artefact',
      'artist',
      'artwork',
      'ask',
      'aspect',
      'assault',
      'asset',
      'assist',
      'assume',
      'asthma',
      'athlete',
      'atom',
      'attack',
      'attend',
      'attitude',
      'attract',
      'auction',
      'audit',
      'august',
      'aunt',
      'author',
      'auto',
      'autumn',
      'average',
      'avocado',
      'avoid',
      'awake',
      'aware',
      'away',
      'awesome',
      'awful',
      'awkward',
      'axis',
    ];
    final wordlist = <String>[...realBip39Prefix];
    // Fill remainder with deterministic slugs until 2048 words.
    int idx = wordlist.length;
    int seed = 42;
    while (wordlist.length < 2048) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      final slug = 'w${idx.toString().padLeft(4, '0')}';
      wordlist.add(slug);
      idx++;
    }
    return wordlist;
  }
}

/// Thrown when a BIP-39 checksum fails validation.
class Bip39ChecksumError implements Exception {
  const Bip39ChecksumError();
  @override
  String toString() => 'Bip39ChecksumError: BIP39_CHECKSUM_FAIL';
}

// ─── Argon2id stub — §2.2 ────────────────────────────────────────────────────

/// Argon2id Key Derivation Function stub.
///
/// Production code uses libsodium `crypto_pwhash` (Argon2id).
/// This stub uses iterated HMAC-SHA256 as a functionally-equivalent stand-in
/// for unit tests (NOT cryptographically equivalent to Argon2id).
///
/// Parameter floor (enforced by [WrappedBlob.wrap]): m_min=16 MiB, t_min=4.
/// A `kdf_version: u8` byte in the blob enables floor upgrades without
/// invalidating existing blobs.
class Argon2idStub {
  Argon2idStub._();

  static const int mMinKib = 16 * 1024; // 16 MiB
  static const int tMin = 4;

  /// Derive a 32-byte key from [password] + [salt].
  ///
  /// [mKib] and [iterations] must meet the floor; throws
  /// [KdfParamsTooWeakError] otherwise.
  static Uint8List derive({
    required Uint8List password,
    required List<int> salt,
    required int mKib,
    required int iterations,
  }) {
    if (mKib < mMinKib) throw KdfParamsTooWeakError(mKib: mKib, t: iterations);
    if (iterations < tMin) {
      throw KdfParamsTooWeakError(mKib: mKib, t: iterations);
    }
    // Stub: iterated HMAC-SHA256 (not Argon2id; for test use only).
    var state = Uint8List.fromList(
      sha256.convert([...password, ...salt]).bytes,
    );
    // Simulate parameter-dependent stretching (iterations rounds).
    for (int i = 0; i < iterations; i++) {
      final hmac = Hmac(sha256, salt);
      state = Uint8List.fromList(hmac.convert([...state, i & 0xFF]).bytes);
    }
    return state;
  }
}

/// Thrown when Argon2id parameters are below the required floor.
class KdfParamsTooWeakError implements Exception {
  final int mKib;
  final int t;
  const KdfParamsTooWeakError({required this.mKib, required this.t});
  @override
  String toString() =>
      'KdfParamsTooWeakError: m=$mKib KiB t=$t is below floor '
      '(m_min=${Argon2idStub.mMinKib} KiB, t_min=${Argon2idStub.tMin})';
}

// ─── WrappedBlob — §2.2 ──────────────────────────────────────────────────────

/// An Argon2id-wrapped account-key blob (≤ 256 bytes).
///
/// Wire layout (CBOR):
///   { 'v': u8, 'm': u32, 't': u8, 'p': u8, 'salt': bytes(16),
///     'blob': bytes(48) } // AES-wrapped 32-byte key + 16-byte tag
class WrappedBlob {
  static const int kVersion = 1;
  static const int kSaltLen = 16;

  final int kdfVersion;
  final int mKib;
  final int iterations;
  final Uint8List salt;
  final Uint8List ciphertext; // wrapped 32-byte key + 16-byte HMAC tag

  WrappedBlob._({
    required this.kdfVersion,
    required this.mKib,
    required this.iterations,
    required this.salt,
    required this.ciphertext,
  });

  /// Wrap a 32-byte [accountKey] with [kek] using AEAD stub.
  ///
  /// [kek] is derived from the recovery code via [Argon2idStub.derive].
  /// [aad] is used as AEAD additional data (account_pub || kdf_params).
  factory WrappedBlob.wrap({
    required Uint8List accountKey,
    required Uint8List kek,
    required Uint8List aad,
    int mKib = Argon2idStub.mMinKib,
    int iterations = Argon2idStub.tMin,
    Uint8List? salt,
  }) {
    assert(accountKey.length == 32);
    assert(kek.length == 32);
    final s = salt ?? _randomBytes(kSaltLen);
    // Encrypt: XOR accountKey with HMAC-SHA256(kek, salt || aad || 0x01).
    final hmacKey = Hmac(sha256, kek);
    final encInput = [...s, ...aad, 0x01];
    final keystream = Uint8List.fromList(hmacKey.convert(encInput).bytes);
    final ct = Uint8List(32);
    for (int i = 0; i < 32; i++) ct[i] = accountKey[i] ^ keystream[i];
    // Tag: HMAC-SHA256(kek, salt || aad || ct)
    final tagInput = [...s, ...aad, ...ct];
    final tag = Uint8List.fromList(hmacKey.convert(tagInput).bytes);
    // ciphertext = ct(32) + tag(32) = 64 bytes; with header ≤ 256 bytes total
    final combined = Uint8List(64)
      ..setRange(0, 32, ct)
      ..setRange(32, 64, tag);
    return WrappedBlob._(
      kdfVersion: kVersion,
      mKib: mKib,
      iterations: iterations,
      salt: s,
      ciphertext: combined,
    );
  }

  /// Unwrap the account key using [kek].
  ///
  /// Throws [BlobIntegrityError] if the AEAD tag doesn't verify.
  Uint8List unwrap({required Uint8List kek, required Uint8List aad}) {
    assert(kek.length == 32);
    final hmacKey = Hmac(sha256, kek);
    final ct = ciphertext.sublist(0, 32);
    final tag = ciphertext.sublist(32, 64);
    // Verify tag.
    final tagInput = [...salt, ...aad, ...ct];
    final expectedTag = Uint8List.fromList(hmacKey.convert(tagInput).bytes);
    int diff = 0;
    for (int i = 0; i < 32; i++) diff |= tag[i] ^ expectedTag[i];
    if (diff != 0) throw BlobIntegrityError();
    // Decrypt.
    final encInput = [...salt, ...aad, 0x01];
    final keystream = Uint8List.fromList(hmacKey.convert(encInput).bytes);
    final plain = Uint8List(32);
    for (int i = 0; i < 32; i++) plain[i] = ct[i] ^ keystream[i];
    return plain;
  }

  /// Encode to bytes (CBOR-like minimal encoding, ≤ 256 bytes).
  Uint8List encode() {
    // Simple byte layout: v(1) + m(4) + t(1) + p(1) + salt(16) + ct(64) = 87
    final buf = Uint8List(87);
    buf[0] = kdfVersion;
    buf[1] = (mKib >> 24) & 0xFF;
    buf[2] = (mKib >> 16) & 0xFF;
    buf[3] = (mKib >> 8) & 0xFF;
    buf[4] = mKib & 0xFF;
    buf[5] = iterations;
    buf[6] = 1; // p=1 (parallelism)
    buf.setRange(7, 23, salt);
    buf.setRange(23, 87, ciphertext);
    return buf;
  }

  /// Decode from bytes produced by [encode].
  factory WrappedBlob.decode(Uint8List data) {
    if (data.length < 87) throw FormatException('WrappedBlob too short');
    final kdfVersion = data[0];
    final mKib = (data[1] << 24) | (data[2] << 16) | (data[3] << 8) | data[4];
    final iterations = data[5];
    final salt = data.sublist(7, 23);
    final ciphertext = data.sublist(23, 87);
    return WrappedBlob._(
      kdfVersion: kdfVersion,
      mKib: mKib,
      iterations: iterations,
      salt: salt,
      ciphertext: ciphertext,
    );
  }
}

/// Thrown when [WrappedBlob.unwrap] fails the integrity check.
class BlobIntegrityError implements Exception {
  const BlobIntegrityError();
  @override
  String toString() => 'BlobIntegrityError: blob integrity check failed';
}

// ─── SessionKdf — §2.3 ───────────────────────────────────────────────────────

/// Per-session X25519 ephemeral key exchange and HKDF key derivation.
///
/// Production: X25519 via libsodium `crypto_scalarmult_curve25519`.
/// Stub: uses SHA-256 based key agreement for unit tests.
class SessionKdf {
  SessionKdf._();

  /// Generate a fresh X25519 ephemeral keypair (stub: random 32-byte pair).
  static EphemeralKeyPair generateEphemeral() {
    final privateKey = _randomBytes(32);
    // Derive public key as SHA-256(private || 0x01) — deterministic.
    final pubInput = Uint8List(33)
      ..setRange(0, 32, privateKey)
      ..[32] = 0x02;
    final publicKey = Uint8List.fromList(sha256.convert(pubInput).bytes);
    return EphemeralKeyPair(publicKey: publicKey, privateKey: privateKey);
  }

  /// Compute the ECDH shared secret (stub: SHA-256(myPriv || theirPub)).
  static Uint8List sharedSecret({
    required Uint8List myPrivateKey,
    required Uint8List theirPublicKey,
  }) {
    final input = Uint8List(64)
      ..setRange(0, 32, myPrivateKey)
      ..setRange(32, 64, theirPublicKey);
    return Uint8List.fromList(sha256.convert(input).bytes);
  }

  /// Derive the session master key.
  ///
  /// `session_master = HKDF-SHA256(ECDH, salt=session_id,
  ///                               info="chessrecast/p2p/v1/master", L=32)`
  static Uint8List sessionMaster({
    required Uint8List ecdhSecret,
    required Uint8List sessionId,
  }) {
    return _hkdf(
      inputKeyMaterial: ecdhSecret,
      salt: sessionId,
      info: 'chessrecast/p2p/v1/master',
      length: 32,
    );
  }

  /// Derive all sub-keys from [sessionMaster].
  ///
  /// Returns a [MasterKeyBundle] with all required per-purpose keys.
  static MasterKeyBundle deriveSubkeys(Uint8List sessionMaster) {
    final dirs = ['a2b', 'b2a'];
    return MasterKeyBundle(
      kAeadChessA2b: _hkdf(
        inputKeyMaterial: sessionMaster,
        salt: Uint8List(0),
        info: 'chessrecast/p2p/v1/aead-chess-a2b',
        length: 32,
      ),
      kAeadChessB2a: _hkdf(
        inputKeyMaterial: sessionMaster,
        salt: Uint8List(0),
        info: 'chessrecast/p2p/v1/aead-chess-b2a',
        length: 32,
      ),
      kAeadClockA2b: _hkdf(
        inputKeyMaterial: sessionMaster,
        salt: Uint8List(0),
        info: 'chessrecast/p2p/v1/aead-clock-a2b',
        length: 32,
      ),
      kAeadClockB2a: _hkdf(
        inputKeyMaterial: sessionMaster,
        salt: Uint8List(0),
        info: 'chessrecast/p2p/v1/aead-clock-b2a',
        length: 32,
      ),
      kTranscriptKdf: _hkdf(
        inputKeyMaterial: sessionMaster,
        salt: Uint8List(0),
        info: 'chessrecast/p2p/v1/transcript-sign',
        length: 32,
      ),
      kViewTemplate: _hkdf(
        inputKeyMaterial: sessionMaster,
        salt: Uint8List(0),
        info: 'chessrecast/p2p/v1/transcript-backup',
        length: 32,
      ),
    );
  }
}

/// An ephemeral X25519 keypair.
class EphemeralKeyPair {
  final Uint8List publicKey; // 32 bytes
  final Uint8List privateKey; // 32 bytes

  const EphemeralKeyPair({required this.publicKey, required this.privateKey});
}

/// All derived sub-keys for a session (§2.3 key separation).
class MasterKeyBundle {
  final Uint8List kAeadChessA2b;
  final Uint8List kAeadChessB2a;
  final Uint8List kAeadClockA2b;
  final Uint8List kAeadClockB2a;
  final Uint8List kTranscriptKdf;
  final Uint8List kViewTemplate;

  const MasterKeyBundle({
    required this.kAeadChessA2b,
    required this.kAeadChessB2a,
    required this.kAeadClockA2b,
    required this.kAeadClockB2a,
    required this.kTranscriptKdf,
    required this.kViewTemplate,
  });

  /// Returns all keys; none may be equal to another (key separation check).
  List<Uint8List> get allKeys => [
    kAeadChessA2b,
    kAeadChessB2a,
    kAeadClockA2b,
    kAeadClockB2a,
    kTranscriptKdf,
    kViewTemplate,
  ];
}

// ─── AeadCipher — §2.3 XChaCha20-Poly1305 stub ───────────────────────────────

/// XChaCha20-Poly1305 AEAD stub for P2P frame encryption.
///
/// Wire nonce structure: `salt_15 || dir_1 || seq_u64_be` = 24 bytes.
///   - `salt_15` is derived via HKDF from session_master (never on wire).
///   - `dir` is 0x00 (A→B) or 0x01 (B→A).
///   - `seq` is the per-direction monotonic sequence counter.
///
/// Defensive ceiling: `seq >= 2^63` triggers `SeqCeilingReachedError`.
///
/// Production: libsodium `crypto_aead_xchacha20poly1305_ietf_encrypt`.
/// Stub: HMAC-SHA256 based authenticated encryption.
class AeadCipher {
  final Uint8List key; // 32-byte symmetric key
  final Uint8List salt15; // 15-byte nonce salt (derived, never on wire)
  final int direction; // 0 = A→B, 1 = B→A
  int _seq = 0;
  int _lastSeenSeq = -1;

  static const int kSeqCeiling = 1 << 62; // well below 2^63

  AeadCipher({
    required this.key,
    required this.salt15,
    required this.direction,
  });

  /// Derive the 15-byte AEAD salt from session_master + session_id.
  ///
  /// `salt_15 = HKDF-SHA256(shared_secret, salt=session_id,
  ///                        info="chessrecast/p2p/v1/aead-salt", L=15)`
  static Uint8List deriveSalt15({
    required Uint8List sharedSecret,
    required Uint8List sessionId,
  }) {
    return _hkdf(
      inputKeyMaterial: sharedSecret,
      salt: sessionId,
      info: 'chessrecast/p2p/v1/aead-salt',
      length: 15,
    );
  }

  /// Encrypt [plaintext] with AAD, returning ciphertext + 32-byte tag.
  ///
  /// Increments the internal sequence counter.
  Uint8List encrypt(Uint8List plaintext, {required Uint8List aad}) {
    if (_seq >= kSeqCeiling) throw SeqCeilingReachedError();
    final nonce = _buildNonce(_seq);
    _seq++;
    // Stub: XOR plaintext with HMAC-SHA256(key, nonce), then append HMAC tag.
    final hmac = Hmac(sha256, key);
    final keystream = Uint8List.fromList(hmac.convert(nonce).bytes);
    final ct = Uint8List(plaintext.length);
    for (int i = 0; i < plaintext.length; i++) {
      ct[i] = plaintext[i] ^ keystream[i % 32];
    }
    final tagInput = [...nonce, ...aad, ...ct];
    final tag = Uint8List.fromList(hmac.convert(tagInput).bytes);
    return Uint8List(ct.length + 32)
      ..setRange(0, ct.length, ct)
      ..setRange(ct.length, ct.length + 32, tag);
  }

  /// Decrypt [ciphertext] (including 32-byte tag), verifying AAD.
  ///
  /// Throws [OutOfSequenceAeadError] if seq ≤ lastSeen.
  /// Throws [AeadDecryptError] on tag mismatch.
  Uint8List decrypt(
    Uint8List ciphertext, {
    required Uint8List aad,
    required int seq,
  }) {
    if (seq <= _lastSeenSeq) throw OutOfSequenceAeadError(seq, _lastSeenSeq);
    _lastSeenSeq = seq;
    if (ciphertext.length < 32) throw AeadDecryptError();
    final ct = ciphertext.sublist(0, ciphertext.length - 32);
    final tag = ciphertext.sublist(ciphertext.length - 32);
    final nonce = _buildNonce(seq);
    final hmac = Hmac(sha256, key);
    // Verify tag.
    final tagInput = [...nonce, ...aad, ...ct];
    final expectedTag = Uint8List.fromList(hmac.convert(tagInput).bytes);
    int diff = 0;
    for (int i = 0; i < 32; i++) diff |= tag[i] ^ expectedTag[i];
    if (diff != 0) throw AeadDecryptError();
    // Decrypt.
    final keystream = Uint8List.fromList(hmac.convert(nonce).bytes);
    final plain = Uint8List(ct.length);
    for (int i = 0; i < ct.length; i++) {
      plain[i] = ct[i] ^ keystream[i % 32];
    }
    return plain;
  }

  int get nextSeq => _seq;

  Uint8List _buildNonce(int seq) {
    // nonce = salt_15 || dir_1 || seq_u64_be
    final n = Uint8List(24);
    n.setRange(0, 15, salt15);
    n[15] = direction & 0xFF;
    // Big-endian seq (8 bytes)
    for (int i = 0; i < 8; i++) {
      n[16 + i] = (seq >> (56 - 8 * i)) & 0xFF;
    }
    return n;
  }
}

/// Thrown when the AEAD sequence counter hits the defensive ceiling (2^62).
class SeqCeilingReachedError implements Exception {
  const SeqCeilingReachedError();
  @override
  String toString() => 'SeqCeilingReachedError: SEQ_CEILING_REACHED';
}

/// Thrown when a received sequence number is not strictly increasing.
class OutOfSequenceAeadError implements Exception {
  final int received;
  final int lastSeen;
  const OutOfSequenceAeadError(this.received, this.lastSeen);
  @override
  String toString() =>
      'OutOfSequenceAeadError: OUT_OF_SEQUENCE received=$received lastSeen=$lastSeen';
}

/// Thrown when AEAD decryption fails the integrity check.
class AeadDecryptError implements Exception {
  const AeadDecryptError();
  @override
  String toString() => 'AeadDecryptError: AEAD_DECRYPT_FAILED';
}

// ─── SafetyNumbers — §2.9 ────────────────────────────────────────────────────

/// Signal-style safety-number computation for TOFU verification.
///
/// `safety_number = base10(SHA-512(min(pkA,pkB) || max(pkA,pkB))[:30])`
/// displayed as 6 groups of 5 digits.
class SafetyNumbers {
  SafetyNumbers._();

  /// Compute the 30-digit safety number for two public keys.
  ///
  /// The computation is symmetric: swapping pkA and pkB produces the same
  /// result (both peers display identical numbers).
  static String compute(Uint8List pkA, Uint8List pkB) {
    final min = _lexLessThan(pkA, pkB) ? pkA : pkB;
    final max = _lexLessThan(pkA, pkB) ? pkB : pkA;
    final buf = Uint8List(64)
      ..setRange(0, 32, min)
      ..setRange(32, 64, max);
    // Use SHA-256 (stub for SHA-512) to produce 30 decimal digits.
    final hash = sha256.convert(buf).bytes;
    // Extract 30 decimal digits from hash bytes (5 digits per 2 bytes).
    final sb = StringBuffer();
    for (int i = 0; i < 6; i++) {
      // Take 2 bytes, mod 100000 to get 5 digits.
      final val = ((hash[i * 2] << 8) | hash[i * 2 + 1]) % 100000;
      sb.write(val.toString().padLeft(5, '0'));
      if (i < 5) sb.write(' ');
    }
    return sb.toString();
  }

  /// Returns true iff pkA < pkB lexicographically.
  static bool _lexLessThan(Uint8List a, Uint8List b) {
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] < b[i]) return true;
      if (a[i] > b[i]) return false;
    }
    return a.length < b.length;
  }
}

// ─── VerifiedContacts — §2.9 ─────────────────────────────────────────────────

/// In-memory store of verified opponent contacts.
///
/// Production: stored in the SQLCipher `verified_contacts` table (§0.6).
/// Tests: in-memory map.
class VerifiedContacts {
  final Map<String, VerifiedContact> _contacts = {};

  /// Record a verification of [theirPublicKey].
  void verify({
    required Uint8List theirPublicKey,
    required VerificationMethod method,
  }) {
    final fingerprint = DeviceFingerprint.compute(theirPublicKey);
    _contacts[fingerprint] = VerifiedContact(
      fingerprint: fingerprint,
      publicKey: Uint8List.fromList(theirPublicKey),
      method: method,
      verifiedAt: DateTime.now(),
    );
  }

  /// Look up the verification record for [theirPublicKey], or null if not
  /// verified.
  VerifiedContact? lookup(Uint8List theirPublicKey) {
    final fingerprint = DeviceFingerprint.compute(theirPublicKey);
    return _contacts[fingerprint];
  }

  /// Check whether the public key for a previously-verified contact changed.
  ///
  /// Returns [ContactKeyChangeResult.changed] if a known fingerprint is now
  /// associated with a different public key, [ContactKeyChangeResult.same] if
  /// matching, and [ContactKeyChangeResult.unknown] if the contact is new.
  ContactKeyChangeResult checkKeyChange({
    required Uint8List theirPublicKey,
    required String theirKnownFingerprint,
  }) {
    final existing = _contacts[theirKnownFingerprint];
    if (existing == null) return ContactKeyChangeResult.unknown;
    final newFingerprint = DeviceFingerprint.compute(theirPublicKey);
    if (newFingerprint == theirKnownFingerprint)
      return ContactKeyChangeResult.same;
    return ContactKeyChangeResult.changed;
  }
}

/// A verified opponent contact record.
class VerifiedContact {
  final String fingerprint;
  final Uint8List publicKey;
  final VerificationMethod method;
  final DateTime verifiedAt;

  const VerifiedContact({
    required this.fingerprint,
    required this.publicKey,
    required this.method,
    required this.verifiedAt,
  });
}

enum VerificationMethod { safetyNumbers, qr }

enum ContactKeyChangeResult { same, changed, unknown }

// ─── KciAuthenticator — §2.9 ─────────────────────────────────────────────────

/// Key-Compromise-Impersonation (KCI) defense.
///
/// After the handshake, each peer sends an explicit MAC over [transcriptHash]
/// keyed by K_kci = HKDF(session_master, info="chessrecast/p2p/v1/kci", L=32).
/// Both peers must verify before accepting any MOVE.
class KciAuthenticator {
  final Uint8List kKci; // 32-byte KCI MAC key

  KciAuthenticator({required Uint8List sessionMaster})
    : kKci = _hkdf(
        inputKeyMaterial: sessionMaster,
        salt: Uint8List(0),
        info: 'chessrecast/p2p/v1/kci',
        length: 32,
      );

  /// Generate the KCI MAC for [transcriptHash].
  Uint8List generateMac(Uint8List transcriptHash) {
    final hmac = Hmac(sha256, kKci);
    return Uint8List.fromList(hmac.convert(transcriptHash).bytes);
  }

  /// Verify the KCI MAC. Throws [KciVerifyFailedError] on mismatch.
  void verifyMac(Uint8List transcriptHash, Uint8List mac) {
    final expected = generateMac(transcriptHash);
    int diff = 0;
    for (int i = 0; i < 32; i++) diff |= mac[i] ^ expected[i];
    if (diff != 0) throw KciVerifyFailedError();
  }
}

/// Thrown when KCI MAC verification fails.
class KciVerifyFailedError implements Exception {
  const KciVerifyFailedError();
  @override
  String toString() => 'KciVerifyFailedError: KCI_VERIFY_FAILED';
}

// ─── CryptoSuiteId — §2.6 ────────────────────────────────────────────────────

/// Crypto suite identifier carried in HELLO.
///
/// 0x01 = X25519 + Ed25519 + XChaCha20-Poly1305 + HKDF-SHA256 + Argon2id.
/// Future: 0x02 = hybrid X25519 + ML-KEM-768 (post-quantum).
class CryptoSuiteId {
  static const int kSuiteClassical = 0x01;

  final int value;
  const CryptoSuiteId(this.value);

  bool get isKnown => value == kSuiteClassical;

  /// Negotiate the suite from initiator's proposed id and responder's id.
  ///
  /// Returns the agreed suite, or throws [CryptoSuiteNotNegotiatedError] if
  /// the two peers cannot agree.
  static CryptoSuiteId negotiate(int initiator, int responder) {
    if (initiator == responder && CryptoSuiteId(initiator).isKnown) {
      return CryptoSuiteId(initiator);
    }
    throw CryptoSuiteNotNegotiatedError(initiator, responder);
  }
}

/// Thrown when crypto suite negotiation fails.
class CryptoSuiteNotNegotiatedError implements Exception {
  final int initiator;
  final int responder;
  const CryptoSuiteNotNegotiatedError(this.initiator, this.responder);
  @override
  String toString() =>
      'CryptoSuiteNotNegotiatedError: CRYPTO_SUITE_NOT_NEGOTIATED '
      'initiator=0x${initiator.toRadixString(16)} '
      'responder=0x${responder.toRadixString(16)}';
}

// ─── SessionRekey — §2.10 ────────────────────────────────────────────────────

/// Session re-key protocol (§2.10).
///
/// Procedure: exchange fresh X25519 ephemerals signed under the current
/// session AEAD, then derive a new session_master via
/// `HKDF(prev_session_master || new_ECDH, info="chessrecast/p2p/v1/rekey", L=32)`.
/// A `keygen: u8` counter is bound into AEAD AAD.
class SessionRekey {
  int _keygenCounter = 0;

  int get keygenCounter => _keygenCounter;

  /// Perform a re-key round.
  ///
  /// Returns the new [RekeyResult] containing the updated session master key
  /// and incremented keygen counter.
  RekeyResult rekey({
    required Uint8List prevSessionMaster,
    required Uint8List myNewPrivateKey,
    required Uint8List theirNewPublicKey,
  }) {
    final newEcdh = SessionKdf.sharedSecret(
      myPrivateKey: myNewPrivateKey,
      theirPublicKey: theirNewPublicKey,
    );
    final combined = Uint8List(64)
      ..setRange(0, 32, prevSessionMaster)
      ..setRange(32, 64, newEcdh);
    final newMaster = _hkdf(
      inputKeyMaterial: combined,
      salt: Uint8List(0),
      info: 'chessrecast/p2p/v1/rekey',
      length: 32,
    );
    _keygenCounter++;
    // Zero out prev session master (simulates sodium_memzero in production)
    prevSessionMaster.fillRange(0, prevSessionMaster.length, 0);
    return RekeyResult(
      newSessionMaster: newMaster,
      keygenCounter: _keygenCounter,
    );
  }
}

/// Result of a session re-key operation.
class RekeyResult {
  final Uint8List newSessionMaster;
  final int keygenCounter;
  const RekeyResult({
    required this.newSessionMaster,
    required this.keygenCounter,
  });
}

/// Thrown when session re-key does not complete within the timeout.
class RekeyFailedError implements Exception {
  const RekeyFailedError();
  @override
  String toString() => 'RekeyFailedError: RE_KEY_FAILED';
}

// ─── Internal helpers ────────────────────────────────────────────────────────

final Random _secureRandom = Random.secure();

Uint8List _randomBytes(int length) {
  final bytes = Uint8List(length);
  for (int i = 0; i < length; i++) {
    bytes[i] = _secureRandom.nextInt(256);
  }
  return bytes;
}

/// HKDF-SHA256 implementation.
///
/// Implements RFC 5869 Extract+Expand:
///   PRK = HMAC-SHA256(salt, IKM)
///   OKM = T(1) || T(2) || ...  where T(i) = HMAC-SHA256(PRK, T(i-1) || info || i)
Uint8List _hkdf({
  required Uint8List inputKeyMaterial,
  required Uint8List salt,
  required String info,
  required int length,
}) {
  // Extract
  final saltKey = salt.isEmpty ? Uint8List(32) : salt;
  final prk = Uint8List.fromList(
    Hmac(sha256, saltKey).convert(inputKeyMaterial).bytes,
  );
  // Expand
  final infoBytes = utf8.encode(info);
  final okm = BytesBuilder(copy: false);
  Uint8List prev = Uint8List(0);
  int counter = 1;
  while (okm.length < length) {
    final hmac = Hmac(sha256, prk);
    final input = [...prev, ...infoBytes, counter];
    prev = Uint8List.fromList(hmac.convert(input).bytes);
    okm.add(prev);
    counter++;
  }
  return Uint8List.fromList(okm.toBytes().sublist(0, length));
}

// ─── CoreDumpPrevention — §2.7 ───────────────────────────────────────────────

/// Result of a [CoreDumpPrevention.disable] call.
enum CoreDumpResult {
  /// Core dumps successfully disabled for this process.
  disabled,

  /// Platform does not support programmatic core-dump suppression via this API.
  /// The caller should document this as an accepted risk.
  notSupported,
}

/// Prevents core dumps from containing secret memory.
///
/// On Linux, calls `prctl(PR_SET_DUMPABLE, 0)` via dart:ffi when the native
/// libsodium wrapper is loaded. In test/stub mode (no FFI), returns
/// [CoreDumpResult.notSupported] so tests can still verify the call-site
/// contract without requiring the native library.
class CoreDumpPrevention {
  CoreDumpPrevention._();

  /// Attempt to disable core dumps.
  ///
  /// Returns [CoreDumpResult.disabled] on success,
  /// [CoreDumpResult.notSupported] when the native library is unavailable or
  /// the platform does not support the operation.
  static CoreDumpResult disable() {
    // Stub: production implementation calls prctl via the libsodium FFI wrapper.
    // Until that wrapper is wired, report notSupported so the test can verify
    // the call does not throw.
    return CoreDumpResult.notSupported;
  }
}

// ─── CrashBreadcrumbFilter — §2.7 ────────────────────────────────────────────

/// Filters crash-reporter breadcrumbs to prevent secret-bearing stack frames
/// from being serialised by Sentry / Crashlytics.
///
/// A frame is redacted if its symbol name matches any known libsodium-wrapper
/// or identity-service prefix.
class CrashBreadcrumbFilter {
  CrashBreadcrumbFilter._();

  /// Symbols that indicate a secret-bearing stack frame.
  static const List<String> _redactedPrefixes = [
    'sodium_',
    'crypto_',
    '_hkdf',
    'DeviceIdentity',
    'SessionKdf',
    'AeadCipher',
    'Argon2idStub',
    'WrappedBlob',
    'RecoveryCode',
    'KciAuthenticator',
  ];

  /// Returns `true` if [stackFrame] must NOT be forwarded to the crash reporter.
  static bool shouldRedact(String stackFrame) {
    for (final prefix in _redactedPrefixes) {
      if (stackFrame.contains(prefix)) return true;
    }
    return false;
  }
}

// ─── QrVerification — §2.9 ───────────────────────────────────────────────────

/// Payload encoded in a QR code for in-person identity verification.
class QrVerificationPayload {
  static const int version = 1;

  final Uint8List myPublicKey;
  final Uint8List theirPublicKey;
  final String expectedSafetyNumber;

  const QrVerificationPayload({
    required this.myPublicKey,
    required this.theirPublicKey,
    required this.expectedSafetyNumber,
  });

  /// Returns `true` if [scannedPayload] agrees with the local perspective.
  ///
  /// Both peers must see the same safety number.
  bool verify(QrVerificationPayload scannedPayload) {
    final localNumber = SafetyNumbers.compute(myPublicKey, theirPublicKey);
    final scannedNumber = SafetyNumbers.compute(
      scannedPayload.myPublicKey,
      scannedPayload.theirPublicKey,
    );
    return localNumber == scannedNumber && localNumber == expectedSafetyNumber;
  }
}

/// Thrown when QR safety numbers do not match.
class QrSafetyNumberMismatch implements Exception {
  const QrSafetyNumberMismatch();
  @override
  String toString() =>
      'QrSafetyNumberMismatch: safety number does not match — possible MITM';
}

// ─── RekeyAadBinding — §2.10 ─────────────────────────────────────────────────

/// Constructs the AAD bytes for a re-keyed AEAD session.
///
/// Per §2.10, the `keygen: u8` counter is bound into AAD so that frames from
/// the old key epoch cannot be replayed into the new key epoch.
class RekeyAadBinding {
  RekeyAadBinding._();

  /// Build the AEAD AAD for [wireVersion], [frameType], [sessionId], and
  /// the current [keygenCounter].
  ///
  /// Format: wire_version(1) || frame_type(1) || session_id(N) || keygen(1)
  static Uint8List buildAad({
    required int wireVersion,
    required int frameType,
    required Uint8List sessionId,
    required int keygenCounter,
  }) {
    final buf = Uint8List(3 + sessionId.length);
    buf[0] = wireVersion & 0xFF;
    buf[1] = frameType & 0xFF;
    buf.setRange(2, 2 + sessionId.length, sessionId);
    buf[2 + sessionId.length] = keygenCounter & 0xFF;
    return buf;
  }
}
