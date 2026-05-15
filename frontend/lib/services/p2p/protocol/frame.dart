// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// ─── CBOR Float Rejection ───────────────────────────────────────────────────

/// Thrown when a CBOR-encoded float (major-type-7, 0xf9/0xfa/0xfb) is decoded.
/// Chess never needs floats; admitting them invites NaN/denormal non-determinism.
class CborFloatRejectedError implements Exception {
  const CborFloatRejectedError();
  @override
  String toString() => 'CborFloatRejectedError: CBOR_FLOAT_REJECTED';
}

/// Thrown when a frame with sequence number ≤ last seen is received.
class OutOfSequenceError implements Exception {
  final int received;
  final int lastSeen;
  const OutOfSequenceError(this.received, this.lastSeen);
  @override
  String toString() =>
      'OutOfSequenceError: received n=$received but last_seen=$lastSeen';
}

/// Thrown when the fragment count exceeds the hard ceiling (64).
class ByeFragmentOutOfBoundsError implements Exception {
  const ByeFragmentOutOfBoundsError();
  @override
  String toString() => 'ByeFragmentOutOfBoundsError: BYE_FRAGMENT_OUT_OF_BOUNDS';
}

/// Thrown when a non-BYE frame attempts fragmentation.
class FragmentNotAllowedError implements Exception {
  const FragmentNotAllowedError();
  @override
  String toString() => 'FragmentNotAllowedError: FRAGMENT_NOT_ALLOWED';
}

// ─── Deterministic CBOR Codec ────────────────────────────────────────────────

/// Deterministic CBOR codec (RFC 8949 §4.2).
///
/// Encoding rules enforced:
/// - Sorted map keys (byte-lexicographic on CBOR-encoded key).
/// - Shortest-form integers.
/// - Definite-length only.
/// - Floats (0xf9/0xfa/0xfb) are REJECTED on decode with [CborFloatRejectedError].
class CborCodec {
  CborCodec._();

  /// Encode [value] to deterministic CBOR bytes.
  ///
  /// Supported types: [int] (≥0), [Uint8List], [String], [List], [Map<String,dynamic>],
  /// [bool], [Null].
  static Uint8List encode(dynamic value) {
    final enc = _CborEncoder();
    enc.writeValue(value);
    return enc.finish();
  }

  /// Decode CBOR bytes into a Dart value.
  ///
  /// Throws [CborFloatRejectedError] on any CBOR float.
  /// Throws [FormatException] on malformed or indefinite-length input.
  static dynamic decode(Uint8List data) {
    final dec = _CborDecoder(data, 0);
    final value = dec.readValue();
    if (dec.pos != data.length) {
      throw FormatException(
          'Trailing bytes at position ${dec.pos} of ${data.length}');
    }
    return value;
  }

  /// Re-encode a decoded value and verify byte-identical round-trip.
  ///
  /// Returns true if [original] bytes == encode(decode([original])).
  static bool isDeterministic(Uint8List original) {
    try {
      final decoded = decode(original);
      final reencoded = encode(decoded);
      if (reencoded.length != original.length) return false;
      for (int i = 0; i < original.length; i++) {
        if (original[i] != reencoded[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _CborEncoder {
  final _buf = BytesBuilder(copy: false);

  void writeValue(dynamic value) {
    if (value == null) {
      _buf.addByte(0xf6);
    } else if (value is bool) {
      _buf.addByte(value ? 0xf5 : 0xf4);
    } else if (value is int) {
      if (value >= 0) {
        _writeMajorInt(0, value);
      } else {
        _writeMajorInt(1, -1 - value);
      }
    } else if (value is Uint8List) {
      _writeMajorInt(2, value.length);
      _buf.add(value);
    } else if (value is List<int>) {
      final bytes = Uint8List.fromList(value);
      _writeMajorInt(2, bytes.length);
      _buf.add(bytes);
    } else if (value is String) {
      final encoded = utf8.encode(value);
      _writeMajorInt(3, encoded.length);
      _buf.add(encoded);
    } else if (value is List) {
      _writeMajorInt(4, value.length);
      for (final item in value) {
        writeValue(item);
      }
    } else if (value is Map<String, dynamic>) {
      _writeMap(value);
    } else {
      throw ArgumentError(
          'CborEncoder: unsupported type ${value.runtimeType}');
    }
  }

  void _writeMap(Map<String, dynamic> map) {
    // Deterministic: sort keys by CBOR encoding of key (byte-lexicographic).
    final entries = map.entries.toList();
    entries.sort((a, b) {
      final ae = _encodeKey(a.key);
      final be = _encodeKey(b.key);
      return _lexCmp(ae, be);
    });
    _writeMajorInt(5, entries.length);
    for (final e in entries) {
      writeValue(e.key); // text key
      writeValue(e.value);
    }
  }

  void _writeMajorInt(int major, int value) {
    final majorBit = major << 5;
    if (value <= 23) {
      _buf.addByte(majorBit | value);
    } else if (value <= 0xff) {
      _buf.addByte(majorBit | 24);
      _buf.addByte(value);
    } else if (value <= 0xffff) {
      _buf.addByte(majorBit | 25);
      _buf.addByte((value >> 8) & 0xff);
      _buf.addByte(value & 0xff);
    } else if (value <= 0xffffffff) {
      _buf.addByte(majorBit | 26);
      _buf.addByte((value >> 24) & 0xff);
      _buf.addByte((value >> 16) & 0xff);
      _buf.addByte((value >> 8) & 0xff);
      _buf.addByte(value & 0xff);
    } else {
      _buf.addByte(majorBit | 27);
      for (int i = 7; i >= 0; i--) {
        _buf.addByte((value >> (i * 8)) & 0xff);
      }
    }
  }

  Uint8List _encodeKey(String key) {
    final e = _CborEncoder();
    e.writeValue(key);
    return e.finish();
  }

  int _lexCmp(Uint8List a, Uint8List b) {
    final len = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }

  Uint8List finish() => Uint8List.fromList(_buf.toBytes());
}

class _CborDecoder {
  final Uint8List data;
  int pos;

  _CborDecoder(this.data, this.pos);

  dynamic readValue() {
    if (pos >= data.length) throw FormatException('Unexpected end of CBOR data');
    final b = data[pos++];
    final major = (b >> 5) & 7;
    final info = b & 0x1f;

    switch (major) {
      case 0:
        return _readArg(info);
      case 1:
        return -1 - _readArg(info);
      case 2:
        final len = _readArg(info);
        if (pos + len > data.length) {
          throw FormatException('Byte string truncated');
        }
        final bytes = Uint8List.fromList(data.sublist(pos, pos + len));
        pos += len;
        return bytes;
      case 3:
        final len = _readArg(info);
        if (pos + len > data.length) {
          throw FormatException('Text string truncated');
        }
        final bytes = data.sublist(pos, pos + len);
        pos += len;
        return utf8.decode(bytes);
      case 4:
        final count = _readArg(info);
        final list = <dynamic>[];
        for (int i = 0; i < count; i++) {
          list.add(readValue());
        }
        return list;
      case 5:
        final count = _readArg(info);
        final map = <String, dynamic>{};
        for (int i = 0; i < count; i++) {
          final key = readValue();
          if (key is! String) {
            throw FormatException('Map key must be a text string');
          }
          map[key] = readValue();
        }
        return map;
      case 6:
        // Tags: skip tag number, read tagged item
        _readArg(info);
        return readValue();
      case 7:
        if (info == 20) return false;
        if (info == 21) return true;
        if (info == 22) return null;
        if (info == 25 || info == 26 || info == 27) {
          throw const CborFloatRejectedError();
        }
        if (info == 31) throw FormatException('Indefinite-length break code');
        throw FormatException('Unknown CBOR simple value: $info');
      default:
        throw FormatException('Unknown CBOR major type: $major');
    }
  }

  int _readArg(int info) {
    if (info <= 23) return info;
    if (info == 24) {
      if (pos >= data.length) throw FormatException('Truncated 1-byte arg');
      return data[pos++];
    }
    if (info == 25) {
      if (pos + 2 > data.length) throw FormatException('Truncated 2-byte arg');
      final v = (data[pos] << 8) | data[pos + 1];
      pos += 2;
      return v;
    }
    if (info == 26) {
      if (pos + 4 > data.length) throw FormatException('Truncated 4-byte arg');
      final v = (data[pos] << 24) |
          (data[pos + 1] << 16) |
          (data[pos + 2] << 8) |
          data[pos + 3];
      pos += 4;
      return v;
    }
    if (info == 27) {
      if (pos + 8 > data.length) throw FormatException('Truncated 8-byte arg');
      int v = 0;
      for (int i = 0; i < 8; i++) {
        v = (v << 8) | data[pos++];
      }
      return v;
    }
    throw FormatException('Indefinite-length CBOR is not allowed (info=$info)');
  }
}

// ─── Frame Types ─────────────────────────────────────────────────────────────

enum FrameType {
  hello(0x01),
  helloAck(0x02),
  helloConfirm(0x03),
  move(0x10),
  moveAck(0x11),
  syncReq(0x20),
  syncResp(0x21),
  drawOffer(0x30),
  drawResponse(0x31),
  resign(0x40),
  takebackReq(0x50),
  takebackResponse(0x51),
  chat(0x60),
  ping(0x70),
  pong(0x71),
  bye(0x80),
  byePart(0x81),
  byeFinal(0x82),
  mismatch(0x90),
  colorFlipCommit(0xa0),
  colorFlipReveal(0xa1),
  clockOffsetReq(0xb0),
  clockOffsetResp(0xb1),
  kciMac(0xc0);

  final int id;
  const FrameType(this.id);

  static FrameType? fromId(int id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

// ─── Frame Envelope ──────────────────────────────────────────────────────────

/// Wire-protocol frame envelope.
///
/// Fields per §1 of docs/P2P_PROTOCOL.md:
///   v (u8)   — wire version
///   t (u8)   — frame type
///   n (u64)  — monotonic sequence number (starts at 1)
///   ts (u64) — sender wall-clock ms (informational only)
///   p (bytes) — CBOR-encoded payload bytes
class Frame {
  static const int wireVersion = 1;

  final int version;
  final FrameType type;
  final int sequenceNum;
  final int wallClock;
  final Uint8List payload;

  const Frame({
    required this.type,
    required this.sequenceNum,
    required this.payload,
    this.version = wireVersion,
    this.wallClock = 0,
  });

  /// Encode this frame to deterministic CBOR bytes.
  Uint8List encode() {
    return CborCodec.encode({
      'n': sequenceNum,
      'p': payload,
      't': type.id,
      'ts': wallClock,
      'v': version,
    });
  }

  /// Decode a CBOR-encoded frame.
  ///
  /// Throws [CborFloatRejectedError] if CBOR contains a float.
  /// Throws [FormatException] on malformed input.
  static Frame decode(Uint8List data) {
    final outer = CborCodec.decode(data);
    if (outer is! Map<String, dynamic>) {
      throw const FormatException('Frame must be a CBOR map');
    }
    final v = _requiredInt(outer, 'v');
    final t = _requiredInt(outer, 't');
    final n = _requiredInt(outer, 'n');
    final ts = outer['ts'] as int? ?? 0;
    final p = outer['p'];
    if (p == null) throw const FormatException('Missing frame field: p');

    final frameType = FrameType.fromId(t);
    if (frameType == null) {
      throw FormatException('Unknown frame type: 0x${t.toRadixString(16)}');
    }

    final payloadBytes = p is Uint8List ? p : Uint8List.fromList(p as List<int>);
    return Frame(
      version: v,
      type: frameType,
      sequenceNum: n,
      wallClock: ts,
      payload: payloadBytes,
    );
  }

  static int _requiredInt(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) throw FormatException('Missing frame field: $key');
    if (v is! int) throw FormatException('Frame field $key must be an int');
    return v;
  }

  /// Create a frame with a CBOR-encoded payload map.
  static Frame withPayloadMap(
    FrameType type,
    Map<String, dynamic> payloadMap, {
    required int sequenceNum,
    int wallClock = 0,
  }) {
    return Frame(
      type: type,
      sequenceNum: sequenceNum,
      wallClock: wallClock,
      payload: CborCodec.encode(payloadMap),
    );
  }

  /// Decode the payload bytes as a CBOR map.
  Map<String, dynamic> decodePayload() {
    final v = CborCodec.decode(payload);
    if (v is! Map<String, dynamic>) {
      throw FormatException(
          'Frame payload must be a CBOR map for type $type');
    }
    return v;
  }
}

// ─── Mod ID ──────────────────────────────────────────────────────────────────

enum ModId {
  classic(0),
  heir(1),
  friendlyFire(2),
  kingsBattle(3),
  mercenary(4),
  saveTheQueen(5),
  succession(6),
  truce(7);

  final int id;
  const ModId(this.id);

  static ModId fromInt(int id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    throw ArgumentError('Unknown mod id: $id');
  }
}

// ─── Move Canonicalization ───────────────────────────────────────────────────

/// Normalises a UCI move string per §9 of P2P_PROTOCOL.md.
///
/// Rules:
/// - Promotion piece is lowercase (e.g. "a7a8q" not "a7a8Q").
/// - Tagged king moves for mod-specific actors use uppercase K prefix:
///   "Ka7a8" for king-A, "Kb7b8" for king-B.
/// - The canonical string is lowercase ASCII except for the optional K prefix.
class MoveCanon {
  MoveCanon._();

  /// Canonicalise a UCI move string.
  ///
  /// [rawUci] is a standard UCI move like "e2e4", "a7a8Q", or a mod-tagged
  /// king move like "Ka7a8" (heir mod).
  static String canonicalise(String rawUci) {
    if (rawUci.isEmpty) return rawUci;

    // Handle mod-tagged king moves (K prefix preserved as uppercase)
    if (rawUci.startsWith('K') || rawUci.startsWith('k')) {
      final prefix = 'K';
      final rest = rawUci.substring(1).toLowerCase();
      return '$prefix$rest';
    }

    // Standard move: lowercase everything
    return rawUci.toLowerCase();
  }

  /// Returns true if [uci] is syntactically valid (not semantically legal).
  ///
  /// Valid patterns:
  ///   - standard: [a-h][1-8][a-h][1-8][qrbn]?
  ///   - tagged king: K[a-h][1-8][a-h][1-8]
  static bool isValidSyntax(String uci) {
    if (uci.isEmpty) return false;
    if (uci.startsWith('K')) {
      // Tagged king: K[a-h][1-8][a-h][1-8]
      final body = uci.substring(1).toLowerCase();
      return RegExp(r'^[a-h][1-8][a-h][1-8]$').hasMatch(body);
    }
    return RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(uci.toLowerCase());
  }
}

// ─── Canonical State Hash ────────────────────────────────────────────────────

/// Computes the canonical state hash for cross-peer verification.
///
/// state_hash = SHA-256(canonical_fen_utf8 || mod_id_byte || mod_state_cbor_bytes)
class StateHasher {
  StateHasher._();

  /// Compute state hash from a FEN string, mod id, and mod-specific state bytes.
  static Uint8List compute(String fen, ModId mod, Uint8List modStateBytes) {
    final fenBytes = utf8.encode(fen);
    final input = Uint8List(fenBytes.length + 1 + modStateBytes.length);
    input.setRange(0, fenBytes.length, fenBytes);
    input[fenBytes.length] = mod.id;
    input.setRange(fenBytes.length + 1, input.length, modStateBytes);
    final digest = sha256.convert(input);
    return Uint8List.fromList(digest.bytes);
  }

  /// Compute state hash with empty mod state (classic chess).
  static Uint8List computeClassic(String fen, ModId mod) {
    return compute(fen, mod, Uint8List(0));
  }
}

// ─── Session ID Derivation ───────────────────────────────────────────────────

/// Derives a collision-resistant session ID from both peers' ephemeral public
/// keys and nonces, per §11 of P2P_PROTOCOL.md.
///
/// session_id = SHA-256(
///   min(eph_a_pub, eph_b_pub) || max(eph_a_pub, eph_b_pub) ||
///   min(nonce_a, nonce_b)     || max(nonce_a, nonce_b)
/// )
///
/// Neither peer can choose session_id unilaterally; no wire field carries it.
class SessionIdDeriver {
  SessionIdDeriver._();

  static Uint8List derive({
    required Uint8List ephPubA,
    required Uint8List ephPubB,
    required Uint8List nonceA,
    required Uint8List nonceB,
  }) {
    final mn1 = _lex(ephPubA, ephPubB) <= 0 ? ephPubA : ephPubB;
    final mx1 = _lex(ephPubA, ephPubB) <= 0 ? ephPubB : ephPubA;
    final mn2 = _lex(nonceA, nonceB) <= 0 ? nonceA : nonceB;
    final mx2 = _lex(nonceA, nonceB) <= 0 ? nonceB : nonceA;

    final buf = BytesBuilder(copy: false);
    buf.add(mn1);
    buf.add(mx1);
    buf.add(mn2);
    buf.add(mx2);
    final digest = sha256.convert(buf.toBytes());
    return Uint8List.fromList(digest.bytes);
  }

  static int _lex(Uint8List a, Uint8List b) {
    final len = a.length < b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }
}

// ─── HKDF Info-String Registry ───────────────────────────────────────────────

/// All registered HKDF info strings for chessrecast/p2p protocol.
/// New labels must be added here AND cited in docs/P2P_PROTOCOL.md §12.
const Map<String, _HkdfLabel> kHkdfInfoRegistry = {
  'chessrecast/p2p/v1/master': _HkdfLabel(
      purpose: 'Session master key from ECDH', outputLength: 32),
  'chessrecast/p2p/v1/aead-salt': _HkdfLabel(
      purpose: 'AEAD nonce salt (never transmitted)', outputLength: 15),
  'chessrecast/p2p/v1/kci': _HkdfLabel(
      purpose: 'KCI defense MAC key', outputLength: 32),
  'chessrecast/p2p/v1/transcript-sign': _HkdfLabel(
      purpose: 'Transcript signing subkey seed', outputLength: 32),
  'chessrecast/p2p/v1/transcript-backup': _HkdfLabel(
      purpose: 'Opt-in encrypted backup key', outputLength: 32),
  'chessrecast/p2p/v1/rekey': _HkdfLabel(
      purpose: 'Session re-key chained master', outputLength: 32),
  'chessrecast/p2p/v1/forensic-at-rest': _HkdfLabel(
      purpose: 'At-rest forensic bundle encryption key', outputLength: 32),
};

class _HkdfLabel {
  final String purpose;
  final int outputLength;
  const _HkdfLabel({required this.purpose, required this.outputLength});
}

// ─── Color Flip Protocol ─────────────────────────────────────────────────────

/// Implements the commit-reveal coin flip for random color assignment.
///
/// Per §13 of P2P_PROTOCOL.md, each peer generates 256-bit random `r`,
/// sends SHA-256(r) as a commit, then reveals `r`.
/// Final color = SHA-256(r_init || r_resp).lsb → 0=white,1=black for initiator.
class ColorFlip {
  ColorFlip._();

  /// Compute the commit hash for a random value `r`.
  static Uint8List computeCommit(Uint8List r) {
    final digest = sha256.convert(r);
    return Uint8List.fromList(digest.bytes);
  }

  /// Verify that a revealed `r` matches the previously-received `commit`.
  static bool verifyReveal(Uint8List commit, Uint8List r) {
    final expected = computeCommit(r);
    if (expected.length != commit.length) return false;
    // Constant-time comparison
    int diff = 0;
    for (int i = 0; i < expected.length; i++) {
      diff |= expected[i] ^ commit[i];
    }
    return diff == 0;
  }

  /// Determine the final color assignment.
  ///
  /// Returns 0 if initiator gets white, 1 if initiator gets black.
  static int resolveColor(Uint8List rInitiator, Uint8List rResponder) {
    final buf = BytesBuilder(copy: false);
    buf.add(rInitiator);
    buf.add(rResponder);
    final seed = sha256.convert(buf.toBytes());
    return seed.bytes.last & 0x01;
  }

  /// Build a COLOR_FLIP_COMMIT payload map.
  static Map<String, dynamic> buildCommitPayload(Uint8List commit) {
    return {'hash': commit};
  }

  /// Build a COLOR_FLIP_REVEAL payload map.
  static Map<String, dynamic> buildRevealPayload(Uint8List r) {
    return {'r': r};
  }
}

// ─── Chat Rate Limiter ────────────────────────────────────────────────────────

/// Per-side chat rate limiter: 10 messages / 30 s sliding window,
/// hard ceiling 200 messages per game.
class ChatRateLimiter {
  static const int _windowMs = 30000;
  static const int _maxPerWindow = 10;
  static const int _maxPerGame = 200;

  final List<int> _timestamps = [];
  int _total = 0;

  /// Check if the next message is allowed.
  ///
  /// [nowMs] — current time in milliseconds (use [DateTime.now().millisecondsSinceEpoch]).
  /// Returns true if the message is allowed; false if rate-limited.
  bool canSend(int nowMs) {
    if (_total >= _maxPerGame) return false;

    // Purge expired timestamps
    final cutoff = nowMs - _windowMs;
    _timestamps.removeWhere((ts) => ts < cutoff);

    return _timestamps.length < _maxPerWindow;
  }

  /// Record that a message was sent at [nowMs].
  void record(int nowMs) {
    _timestamps.add(nowMs);
    _total++;
  }

  int get totalSent => _total;
  int get recentCount => _timestamps.length;
}

// ─── Draw Offer Lifecycle ─────────────────────────────────────────────────────

enum DrawOfferState { none, pending, expired }

/// Manages draw offer lifecycle per §14 of P2P_PROTOCOL.md:
/// - offer auto-expires after 60 s
/// - offer retracted implicitly by next MOVE
/// - throttle: 1 per 10 plies + at-will when opponent clock < 30 s
class DrawOfferLifecycle {
  static const int _offerTimeoutMs = 60000;
  static const int _throttlePlies = 10;

  DrawOfferState _state = DrawOfferState.none;
  int _offerTs = 0;
  int _lastOfferPly = -_throttlePlies - 1; // allow first offer immediately

  DrawOfferState get state => _state;

  /// Returns true if we can send a draw offer now.
  bool canOffer(int nowMs, int currentPly, {bool opponentClockLt30s = false}) {
    if (_state == DrawOfferState.pending) return false; // already pending
    if (opponentClockLt30s) return true;
    return (currentPly - _lastOfferPly) >= _throttlePlies;
  }

  /// Record that we sent a draw offer.
  void sendOffer(int nowMs, int currentPly) {
    _state = DrawOfferState.pending;
    _offerTs = nowMs;
    _lastOfferPly = currentPly;
  }

  /// Called when the local side makes a MOVE — retracts any pending offer.
  void retractOnMove() {
    _state = DrawOfferState.none;
  }

  /// Tick the lifecycle; expires an offer if 60 s have elapsed.
  ///
  /// Returns true if the offer expired this tick.
  bool tick(int nowMs) {
    if (_state == DrawOfferState.pending &&
        nowMs - _offerTs >= _offerTimeoutMs) {
      _state = DrawOfferState.expired;
      return true;
    }
    return false;
  }

  /// Record that the opponent responded (accepted or declined).
  void onResponse() {
    _state = DrawOfferState.none;
  }
}

// ─── BYE Fragmentation ───────────────────────────────────────────────────────

/// Maximum BYE payload bytes before fragmentation is required.
const int kByeFragmentThresholdBytes = 12 * 1024; // 12 KB
/// Maximum number of BYE_PART frames (hard ceiling to prevent DoS).
const int kByeMaxFragments = 64;

/// Splits a large BYE payload into BYE_PART + BYE_FINAL frames.
class ByeFragmenter {
  ByeFragmenter._();

  static const int _chunkSize = 12 * 1024;

  /// Fragments [byePayloadBytes] into a sequence of CBOR payload maps:
  /// first N-1 are BYE_PART, last is BYE_FINAL.
  ///
  /// Throws [ByeFragmentOutOfBoundsError] if too many chunks needed.
  /// Throws [FragmentNotAllowedError] if input is too small to need fragmentation.
  static List<Map<String, dynamic>> fragment(Uint8List byePayloadBytes) {
    if (byePayloadBytes.length <= kByeFragmentThresholdBytes) {
      throw const FragmentNotAllowedError();
    }

    final chunks = <Uint8List>[];
    for (int offset = 0; offset < byePayloadBytes.length; offset += _chunkSize) {
      final end = (offset + _chunkSize) < byePayloadBytes.length
          ? offset + _chunkSize
          : byePayloadBytes.length;
      chunks.add(Uint8List.fromList(byePayloadBytes.sublist(offset, end)));
    }

    if (chunks.length > kByeMaxFragments) {
      throw const ByeFragmentOutOfBoundsError();
    }

    final payloads = <Map<String, dynamic>>[];
    for (int i = 0; i < chunks.length; i++) {
      payloads.add({
        'idx': i,
        'tot': chunks.length,
        'data': chunks[i],
      });
    }

    // Final frame: hash of all data
    final allBytes = BytesBuilder(copy: false);
    for (final c in chunks) {
      allBytes.add(c);
    }
    final hash =
        Uint8List.fromList(sha256.convert(allBytes.toBytes()).bytes);
    // The caller should append a BYE_FINAL payload separately
    // We embed the hash in the last BYE_PART and return it as-is.
    // BYE_FINAL is a separate frame with just {hash, sig}.
    payloads.add({'hash': hash});
    return payloads;
  }

  /// Reassemble BYE_PART frames into the original payload bytes.
  ///
  /// [parts] must be in order (sorted by idx).
  /// Returns reassembled bytes if valid; throws on error.
  static Uint8List reassemble(List<Map<String, dynamic>> parts,
      Uint8List expectedHash) {
    if (parts.isEmpty) throw const FormatException('No BYE_PART frames');
    final total = parts.first['tot'] as int;
    if (total > kByeMaxFragments) throw const ByeFragmentOutOfBoundsError();

    final sorted = [...parts]
      ..sort((a, b) => (a['idx'] as int).compareTo(b['idx'] as int));

    final buf = BytesBuilder(copy: false);
    for (int i = 0; i < sorted.length; i++) {
      if ((sorted[i]['idx'] as int) != i) {
        throw FormatException('Missing BYE_PART idx=$i');
      }
      buf.add(sorted[i]['data'] as Uint8List);
    }

    final assembled = buf.toBytes();
    final actualHash =
        Uint8List.fromList(sha256.convert(assembled).bytes);

    // Constant-time comparison
    if (actualHash.length != expectedHash.length) {
      throw const FormatException('BYE hash length mismatch');
    }
    int diff = 0;
    for (int i = 0; i < actualHash.length; i++) {
      diff |= actualHash[i] ^ expectedHash[i];
    }
    if (diff != 0) throw const FormatException('BYE hash mismatch');

    return Uint8List.fromList(assembled);
  }
}

// ─── Repetition Detector ─────────────────────────────────────────────────────

/// Maintains a history of state hashes for three-fold repetition detection.
///
/// History is reset on each irreversible move (capture, pawn move,
/// mod-specific irreversible event per docs/game/DRAW_RULES.md).
class RepetitionDetector {
  final List<Uint8List> _history = [];

  /// Number of positions in history since last irreversible move.
  int get historyLength => _history.length;

  /// Record a position hash after applying a move.
  void push(Uint8List stateHash) {
    _history.add(stateHash);
  }

  /// Reset history on an irreversible move.
  void reset() {
    _history.clear();
  }

  /// Returns how many times [stateHash] appears in the current history.
  int countOccurrences(Uint8List stateHash) {
    int count = 0;
    for (final h in _history) {
      if (_hashEquals(h, stateHash)) count++;
    }
    return count;
  }

  /// True if three-fold repetition is detected (≥ 3 occurrences).
  bool isThreefoldRepetition(Uint8List stateHash) {
    return countOccurrences(stateHash) >= 3;
  }

  /// Verify a repetition claim: [witnessHash] must appear ≥ [occurrences] times.
  bool verifyRepetitionClaim(Uint8List witnessHash, int occurrences) {
    return countOccurrences(witnessHash) >= occurrences;
  }

  static bool _hashEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ─── Resign Frame Signing ────────────────────────────────────────────────────

/// Computes the message to be signed for a RESIGN frame.
///
/// The signed message is: SHA-256("resign" || sessionId || resignPayloadCbor)
/// where resignPayloadCbor excludes the `sig` field.
///
/// Signing is done externally (Phase 2 provides the device private key).
Uint8List resignMessageToSign(Uint8List sessionId, Uint8List resignPayloadCborWithoutSig) {
  final label = utf8.encode('resign');
  final buf = BytesBuilder(copy: false);
  buf.add(label);
  buf.add(sessionId);
  buf.add(resignPayloadCborWithoutSig);
  final digest = sha256.convert(buf.toBytes());
  return Uint8List.fromList(digest.bytes);
}

/// Build a RESIGN frame payload map.
///
/// [signature] is the 64-byte Ed25519 signature from the device long-term key.
Map<String, dynamic> buildResignPayload(Uint8List signature) {
  return {'sig': signature};
}

// ─── BYE Frame Signing ───────────────────────────────────────────────────────

/// Computes the message to be signed for a BYE frame.
///
/// message = SHA-256("bye" || sessionId || byePayloadCborWithoutSig)
Uint8List byeMessageToSign(Uint8List sessionId, Uint8List byePayloadCborWithoutSig) {
  final label = utf8.encode('bye');
  final buf = BytesBuilder(copy: false);
  buf.add(label);
  buf.add(sessionId);
  buf.add(byePayloadCborWithoutSig);
  final digest = sha256.convert(buf.toBytes());
  return Uint8List.fromList(digest.bytes);
}
