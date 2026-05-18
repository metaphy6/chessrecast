// ignore_for_file: constant_identifier_names

/// Spectator key derivation (§7.1 / §7.9.1).
///
/// K_view is a per-spectator view-only AEAD key derived from session_master:
///   K_view = HKDF(session_master,
///                 info="chessrecast/p2p/v1/spectator/view-only/<spectator_pubkey_hex>",
///                 L=32)
///
/// Per-direction chat sub-keys are derived from K_view:
///   K_chat_spec_dir = HKDF(K_view,
///                          info="chessrecast/p2p/v1/spectator-chat/<dir>",
///                          L=32)
///
/// Valid <dir> values: spec_to_host, host_to_spec, host_to_spec_broadcast.
///
/// NOTE: Production uses libsodium crypto_kdf_hkdf_sha256_expand. This
/// pure-Dart implementation uses HMAC-SHA256 HKDF (RFC 5869) for unit tests.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Direction enum for spectator-chat sub-keys.
enum SpectatorChatDir {
  specToHost,
  hostToSpec,
  hostToSpecBroadcast,
}

extension SpectatorChatDirLabel on SpectatorChatDir {
  String get label {
    switch (this) {
      case SpectatorChatDir.specToHost:
        return 'spec→host';
      case SpectatorChatDir.hostToSpec:
        return 'host→spec';
      case SpectatorChatDir.hostToSpecBroadcast:
        return 'host→spec_broadcast';
    }
  }
}

/// HKDF-SHA256 — extract + expand (RFC 5869).
class HkdfSha256 {
  HkdfSha256._();

  /// HKDF-Extract: PRK = HMAC-SHA256(salt, ikm)
  static Uint8List extract(Uint8List salt, Uint8List ikm) {
    final hmac = Hmac(sha256, salt);
    return Uint8List.fromList(hmac.convert(ikm).bytes);
  }

  /// HKDF-Expand: OKM = T(1) || T(2) || ... (RFC 5869 §2.3)
  static Uint8List expand(Uint8List prk, Uint8List info, int length) {
    assert(length <= 32 * 255, 'HKDF expand length exceeds limit');
    final output = <int>[];
    var t = Uint8List(0);
    var counter = 1;
    while (output.length < length) {
      final block = Uint8List(t.length + info.length + 1)
        ..setRange(0, t.length, t)
        ..setRange(t.length, t.length + info.length, info)
        ..[t.length + info.length] = counter;
      final hmac = Hmac(sha256, prk);
      t = Uint8List.fromList(hmac.convert(block).bytes);
      output.addAll(t);
      counter++;
    }
    return Uint8List.fromList(output.sublist(0, length));
  }

  /// Full HKDF: extract then expand.
  static Uint8List derive({
    required Uint8List ikm,
    required Uint8List salt,
    required String info,
    int length = 32,
  }) {
    final prk = extract(salt, ikm);
    final infoBytes = Uint8List.fromList(utf8.encode(info));
    return expand(prk, infoBytes, length);
  }
}

/// Derives [K_view] for a spectator joining [sessionMaster].
///
/// [sessionMaster] — 32-byte session master key
/// [spectatorPubKey] — 32-byte spectator Ed25519 public key
/// [salt] — 32-byte random salt (may be zero-salt if not available)
Uint8List deriveKView({
  required Uint8List sessionMaster,
  required Uint8List spectatorPubKey,
  Uint8List? salt,
}) {
  final spectatorHex = spectatorPubKey
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  final info =
      'chessrecast/p2p/v1/spectator/view-only/$spectatorHex';
  return HkdfSha256.derive(
    ikm: sessionMaster,
    salt: salt ?? Uint8List(32),
    info: info,
    length: 32,
  );
}

/// Derives a per-direction spectator-chat sub-key from [kView].
///
/// [kView] — 32-byte K_view for this spectator
/// [dir] — direction of the chat channel
Uint8List deriveKChatSpecDir({
  required Uint8List kView,
  required SpectatorChatDir dir,
  Uint8List? salt,
}) {
  final info = 'chessrecast/p2p/v1/spectator-chat/${dir.label}';
  return HkdfSha256.derive(
    ikm: kView,
    salt: salt ?? Uint8List(32),
    info: info,
    length: 32,
  );
}
