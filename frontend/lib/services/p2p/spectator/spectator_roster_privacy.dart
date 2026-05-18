// ignore_for_file: constant_identifier_names

/// Spectator roster privacy policy (§7.8.5).
///
/// Spectators see ONLY:
///   - Their own join confirmation.
///   - The game state.
/// Spectators NEVER see:
///   - Other spectators' pubkeys or identities.
///   - The count of other spectators.
///
/// Only the issuing peer (host) sees the full roster for moderation.
///
/// The non-issuing player is completely unaware of spectators.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The roster view returned to each principal.
class SpectatorRosterView {
  /// The spectator's own join confirmation token.
  final String? ownJoinConfirmation;

  /// Full roster — only populated for the issuing peer (host).
  final List<String> fullRoster;

  const SpectatorRosterView({
    this.ownJoinConfirmation,
    this.fullRoster = const [],
  });
}

/// Manages spectator roster and enforces privacy rules.
class SpectatorRosterPrivacy {
  final List<String> _rosterPubKeyHexes = [];

  void addSpectator(Uint8List pubKey) {
    _rosterPubKeyHexes.add(
      pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  void removeSpectator(Uint8List pubKey) {
    final hex = pubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _rosterPubKeyHexes.remove(hex);
  }

  /// Build the roster view for a given requestor type.
  ///
  /// [forIssuingPeer] — true iff the requestor is the host.
  /// [forSpectatorPubKey] — set when a spectator requests their own view.
  SpectatorRosterView viewFor({
    required bool forIssuingPeer,
    Uint8List? forSpectatorPubKey,
  }) {
    if (forIssuingPeer) {
      // Host sees full roster.
      return SpectatorRosterView(fullRoster: List.unmodifiable(_rosterPubKeyHexes));
    }
    if (forSpectatorPubKey != null) {
      // Spectator sees only their own join confirmation.
      final hex = forSpectatorPubKey
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final confirmation = _joinConfirmation(hex);
      return SpectatorRosterView(ownJoinConfirmation: confirmation);
    }
    // Non-issuing player: unaware, empty view.
    return const SpectatorRosterView();
  }

  /// Returns number of spectators (host-only information).
  int get count => _rosterPubKeyHexes.length;

  /// Generates a deterministic join-confirmation token for a spectator.
  static String _joinConfirmation(String pubKeyHex) {
    final digest = sha256.convert(utf8.encode('join:$pubKeyHex'));
    return 'join:${digest.toString().substring(0, 16)}';
  }
}
