// ignore_for_file: constant_identifier_names

/// Persistent spectator ban list (§7.9.5).
///
/// The host can ban an account globally. The ban is persisted locally and
/// enforced both at signaling join time and at fan-out re-encrypt time for
/// any future game this account hosts.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Represents a ban record.
class BanRecord {
  final String accountPubKeyHex;
  final int bannedAtMs;
  final String reason;

  const BanRecord({
    required this.accountPubKeyHex,
    required this.bannedAtMs,
    required this.reason,
  });
}

/// Local persistent ban list for an issuing peer.
///
/// In production this is backed by SQLCipher (§0.6). In unit tests,
/// this in-memory implementation is used.
class BanList {
  final Map<String, BanRecord> _bans = {};

  /// Add an account to the ban list.
  void ban({
    required Uint8List accountPubKey,
    required int nowMs,
    String reason = 'host_ban',
  }) {
    final hex = _toHex(accountPubKey);
    _bans[hex] = BanRecord(
      accountPubKeyHex: hex,
      bannedAtMs: nowMs,
      reason: reason,
    );
  }

  /// Remove a ban (unban).
  void unban(Uint8List accountPubKey) {
    _bans.remove(_toHex(accountPubKey));
  }

  /// Returns true if [accountPubKey] is banned.
  bool isBanned(Uint8List accountPubKey) =>
      _bans.containsKey(_toHex(accountPubKey));

  /// Returns all active bans.
  List<BanRecord> get allBans => List.unmodifiable(_bans.values);

  static String _toHex(Uint8List k) =>
      k.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

// ─── Mute / kick state §7.9.5 ────────────────────────────────────────────────

/// Error codes for mute/kick/ban actions.
const String kSpectatorKicked = 'SPECTATOR_KICKED'; // F-SPEC-005

/// Manages per-spectator mute and kick state for a single game session.
class SpectatorModerationSession {
  final Set<String> _muted = {};
  final Set<String> _kicked = {};

  void mute(Uint8List spectatorPubKey) =>
      _muted.add(_hex(spectatorPubKey));
  void unmute(Uint8List spectatorPubKey) =>
      _muted.remove(_hex(spectatorPubKey));
  void kick(Uint8List spectatorPubKey) {
    _kicked.add(_hex(spectatorPubKey));
    _muted.add(_hex(spectatorPubKey));
  }

  bool isMuted(Uint8List spectatorPubKey) =>
      _muted.contains(_hex(spectatorPubKey));
  bool isKicked(Uint8List spectatorPubKey) =>
      _kicked.contains(_hex(spectatorPubKey));

  static String _hex(Uint8List k) =>
      k.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
