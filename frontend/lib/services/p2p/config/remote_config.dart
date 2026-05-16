// §6.1 / §6.3 Remote configuration service.
//
// Delivers a signed config blob from the signaling server and exposes the
// `kEnableP2P` feature flag. The blob is HMAC-SHA256-signed so the client
// can verify it has not been tampered with in transit.
//
// Kill-switch (§6.3): pushing a new signed blob with `kEnableP2P: false`
// flips the flag off within the delivery latency of the next poll cycle.
//
// Replay guard: a blob with a `generatedAtMs` older than the currently
// cached blob's timestamp is silently ignored.
import 'dart:convert';
import 'package:crypto/crypto.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when the HMAC signature of a received config blob does not match.
class RemoteConfigSignatureError implements Exception {
  final String message;
  const RemoteConfigSignatureError(this.message);

  @override
  String toString() => 'RemoteConfigSignatureError: $message';
}

// ---------------------------------------------------------------------------
// Blob
// ---------------------------------------------------------------------------

/// An immutable, signed remote-config payload.
class RemoteConfigBlob {
  final bool kEnableP2P;

  /// Unix time in milliseconds at which the server generated this blob.
  /// Used for the replay-guard: an older blob does not replace a newer one.
  final int generatedAtMs;

  const RemoteConfigBlob({
    required this.kEnableP2P,
    required this.generatedAtMs,
  });

  // ── Serialisation ────────────────────────────────────────────────────────

  /// Returns the canonical bytes to sign / verify.
  List<int> _canonicalBytes() {
    final payload = json.encode({
      'kEnableP2P': kEnableP2P,
      'generatedAtMs': generatedAtMs,
    });
    return utf8.encode(payload);
  }

  /// Signs the blob with HMAC-SHA256 using [keyBytes] and returns the 32-byte
  /// MAC.
  List<int> sign(List<int> keyBytes) {
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(_canonicalBytes()).bytes;
  }

  /// Returns `true` if [sig] is a valid HMAC-SHA256 MAC of this blob under
  /// [keyBytes].
  bool verify(List<int> sig, List<int> keyBytes) {
    final expected = sign(keyBytes);
    if (expected.length != sig.length) return false;
    // Constant-time comparison to prevent timing attacks.
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ sig[i];
    }
    return diff == 0;
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// In-memory remote-configuration service.
///
/// Typical usage:
/// ```dart
/// final svc = RemoteConfigService(trustedKeyBytes: _builtInKey);
/// // ... on network fetch:
/// svc.acceptBlob(parsedBlob, receivedSig);
/// if (svc.isP2PEnabled) { ... }
/// ```
class RemoteConfigService {
  /// The safe default: P2P is disabled until a signed config enables it.
  static const bool kDefaultEnableP2P = false;

  final List<int> _trustedKeyBytes;
  RemoteConfigBlob? _cached;

  RemoteConfigService({required List<int> trustedKeyBytes})
      : _trustedKeyBytes = List.unmodifiable(trustedKeyBytes);

  // ── Accessors ────────────────────────────────────────────────────────────

  /// Whether P2P is currently enabled per the latest verified config.
  /// Returns [kDefaultEnableP2P] when no valid config has been accepted yet.
  bool get isP2PEnabled => _cached?.kEnableP2P ?? kDefaultEnableP2P;

  /// The last successfully verified and cached config blob, or `null`.
  RemoteConfigBlob? get cachedBlob => _cached;

  // ── Accept ───────────────────────────────────────────────────────────────

  /// Verifies [sig] against [blob] and, if valid, replaces the in-memory
  /// cache (subject to the replay guard).
  ///
  /// Throws [RemoteConfigSignatureError] if the signature is invalid.
  void acceptBlob(RemoteConfigBlob blob, List<int> sig) {
    if (!blob.verify(sig, _trustedKeyBytes)) {
      throw const RemoteConfigSignatureError('HMAC signature mismatch');
    }
    // Replay guard: ignore blobs older than the current cache.
    if (_cached != null && blob.generatedAtMs <= _cached!.generatedAtMs) {
      return;
    }
    _cached = blob;
  }

  // ── Cache management ─────────────────────────────────────────────────────

  /// Clears the in-memory cache; [isP2PEnabled] reverts to the safe default.
  void clearCache() => _cached = null;
}
