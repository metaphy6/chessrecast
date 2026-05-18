// ignore_for_file: constant_identifier_names

/// Single-hop fan-out topology (§7.8.1).
///
/// Spectators connect ONLY to the issuing peer (the player who issued K_view).
/// The non-issuing player:
///   - is unaware of spectator count,
///   - never receives spectator DataChannel connections,
///   - does not appear in spectator's peer list,
///   - has zero TURN budget impact from spectators.
///
/// Issuing-peer egress = O(N_spectators).
/// Non-issuing-peer egress = unchanged from private game.
library;

import 'dart:typed_data';

/// Identifies which peer in a game is the "issuing peer" who hands out K_view.
enum PeerRole {
  /// The peer who created the watch invite and issues K_view.
  issuing,

  /// The opponent — unaware of spectators.
  nonIssuing,
}

/// Describes a spectator's channel attachment.
class SpectatorChannel {
  /// The spectator's Ed25519 public key.
  final Uint8List spectatorPubKey;

  /// SCTP stream 1 — chess + clock + back-fill (priority = high).
  static const int streamChess = 1;

  /// SCTP stream 7 — chat + roster (priority = low).
  static const int streamChat = 7;

  SpectatorChannel({required this.spectatorPubKey});
}

/// Tracks which peer issued K_view and the set of connected spectators.
class SpectatorTopology {
  final PeerRole localRole;

  final List<SpectatorChannel> _channels = [];

  SpectatorTopology({required this.localRole});

  /// True when the local peer is the one who distributed K_view.
  bool get isIssuingPeer => localRole == PeerRole.issuing;

  /// True when the local peer is the non-issuing player.
  ///
  /// Non-issuing peers must not maintain any [SpectatorChannel] state.
  bool get isNonIssuingPeer => localRole == PeerRole.nonIssuing;

  /// Number of spectators currently connected to this issuing peer.
  int get spectatorCount => _channels.length;

  /// Register a new spectator channel. Only valid on the issuing peer.
  void addSpectator(SpectatorChannel ch) {
    if (!isIssuingPeer) {
      throw StateError(
        'Non-issuing peer must not track spectators',
      );
    }
    _channels.add(ch);
  }

  /// Remove a spectator channel (on disconnect / eviction).
  void removeSpectator(Uint8List spectatorPubKey) {
    _channels.removeWhere(
      (c) => _bytesEqual(c.spectatorPubKey, spectatorPubKey),
    );
  }

  /// Returns an immutable snapshot of the connected spectator pub-keys.
  /// Returns empty list for non-issuing peers (they are unaware).
  List<Uint8List> get spectatorPubKeys {
    if (!isIssuingPeer) return const [];
    return List.unmodifiable(_channels.map((c) => c.spectatorPubKey));
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
