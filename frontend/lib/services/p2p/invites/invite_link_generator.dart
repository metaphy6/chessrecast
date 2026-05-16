// §6.7.2 Invite-link generation (Dart side).
//
// Token layout (raw bytes, 84 B total, then base64url-encoded — no padding):
//
//   [pubkey 32 B][nonce 16 B][expiry_u32_be 4 B][HMAC-SHA256 32 B]
//
// The HMAC is computed over: pubkey || nonce || expiry_u32_be
// using the caller-supplied secret.  The server side (Go) validates and
// redeems the same layout.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Client-side invite-link generator for §6.7.2.
class InviteLinkGenerator {
  final List<int> _hmacSecret;

  /// [hmacSecret] must be at least 32 bytes of high-entropy key material
  /// shared with the signaling server.
  const InviteLinkGenerator({required List<int> hmacSecret})
      : _hmacSecret = hmacSecret;

  /// Default invite TTL: 24 hours (in seconds).
  static const int defaultTtlSeconds = 24 * 60 * 60;

  /// Generates a single-use invite token for [pubkey] (32 bytes).
  ///
  /// Returns the base64url token (no padding, 112 chars for 84 raw bytes).
  String generate({
    required Uint8List pubkey,
    int ttlSeconds = defaultTtlSeconds,
  }) {
    if (pubkey.length != 32) {
      throw ArgumentError('pubkey must be exactly 32 bytes');
    }

    final nonce = _randomBytes(16);
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + ttlSeconds;
    final expiryBytes = _uint32be(expiry);

    final mac = _computeMac(pubkey, nonce, expiryBytes);

    final raw = Uint8List(84);
    raw.setRange(0, 32, pubkey);
    raw.setRange(32, 48, nonce);
    raw.setRange(48, 52, expiryBytes);
    raw.setRange(52, 84, mac);

    return base64Url.encode(raw).replaceAll('=', '');
  }

  /// Parses [token] and returns its embedded pubkey without verifying the
  /// HMAC signature (the server handles authoritative validation).
  ///
  /// Throws [FormatException] if the token is structurally invalid.
  Uint8List extractPubkey(String token) {
    final padded = _addPadding(token);
    final raw = base64Url.decode(padded);
    if (raw.length != 84) throw const FormatException('Invalid token length');
    return Uint8List.fromList(raw.sublist(0, 32));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  List<int> _computeMac(Uint8List pubkey, Uint8List nonce, Uint8List expiry) {
    final hmacKey = Hmac(sha256, _hmacSecret);
    final payload = Uint8List(52);
    payload.setRange(0, 32, pubkey);
    payload.setRange(32, 48, nonce);
    payload.setRange(48, 52, expiry);
    return hmacKey.convert(payload).bytes;
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rng.nextInt(256)));
  }

  static Uint8List _uint32be(int value) {
    final buf = ByteData(4);
    buf.setUint32(0, value & 0xFFFFFFFF, Endian.big);
    return buf.buffer.asUint8List();
  }

  static String _addPadding(String s) {
    final pad = (4 - s.length % 4) % 4;
    return s + ('=' * pad);
  }
}
