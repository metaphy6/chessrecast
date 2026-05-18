// ignore_for_file: constant_identifier_names

/// Spectator heartbeat and seat reclamation (§7.8.6).
///
/// Every seated spectator sends a heartbeat every 30 s on SCTP stream 1.
/// If two consecutive heartbeats are missed, the issuing peer tears down
/// the channel and reclaims the seat.
///
/// Error code: SPECTATOR_HEARTBEAT_TIMEOUT (F-SPEC-012).
library;

import 'dart:typed_data';

const String kSpectatorHeartbeatTimeout = 'SPECTATOR_HEARTBEAT_TIMEOUT';

/// Tracks heartbeat state for a single spectator.
class SpectatorHeartbeatTracker {
  static const int heartbeatIntervalMs = 30000; // 30 s
  static const int missedToEvict = 2;

  final Uint8List spectatorPubKey;
  int _lastHeartbeatMs;
  int _consecutiveMisses = 0;

  SpectatorHeartbeatTracker({
    required this.spectatorPubKey,
    required int nowMs,
  }) : _lastHeartbeatMs = nowMs;

  /// Record a received heartbeat at [nowMs].
  void onHeartbeat(int nowMs) {
    _lastHeartbeatMs = nowMs;
    _consecutiveMisses = 0;
  }

  /// Check heartbeat state at [nowMs].
  ///
  /// Returns [kSpectatorHeartbeatTimeout] if two consecutive heartbeats
  /// have been missed, null otherwise.
  String? checkAt(int nowMs) {
    final elapsed = nowMs - _lastHeartbeatMs;
    // Count missed intervals.
    final missed = (elapsed / heartbeatIntervalMs).floor();
    if (missed >= missedToEvict) {
      return kSpectatorHeartbeatTimeout;
    }
    return null;
  }

  /// Update the consecutive miss count (called on timer tick).
  ///
  /// Returns true if the spectator should be evicted.
  bool tickAt(int nowMs) {
    final elapsed = nowMs - _lastHeartbeatMs;
    _consecutiveMisses = (elapsed / heartbeatIntervalMs).floor();
    return _consecutiveMisses >= missedToEvict;
  }
}

/// Manages heartbeat trackers for all seated spectators.
class SpectatorHeartbeatManager {
  final Map<String, SpectatorHeartbeatTracker> _trackers = {};

  void registerSpectator({
    required Uint8List spectatorPubKey,
    required int nowMs,
  }) {
    _trackers[_key(spectatorPubKey)] = SpectatorHeartbeatTracker(
      spectatorPubKey: spectatorPubKey,
      nowMs: nowMs,
    );
  }

  void onHeartbeat({required Uint8List spectatorPubKey, required int nowMs}) {
    _trackers[_key(spectatorPubKey)]?.onHeartbeat(nowMs);
  }

  /// Returns pub-keys of spectators that must be evicted.
  List<Uint8List> evictionCandidates(int nowMs) {
    final evict = <Uint8List>[];
    for (final e in _trackers.entries) {
      if (e.value.tickAt(nowMs)) {
        evict.add(e.value.spectatorPubKey);
      }
    }
    return evict;
  }

  void removeSpectator(Uint8List spectatorPubKey) {
    _trackers.remove(_key(spectatorPubKey));
  }

  static String _key(Uint8List k) =>
      k.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
