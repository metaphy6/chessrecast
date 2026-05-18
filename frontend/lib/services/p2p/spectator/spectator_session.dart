// ignore_for_file: constant_identifier_names

/// Spectator session umbrella (§7.1 + §7.6 + §7.8 + §7.9 + §7.10).
///
/// Coordinates all spectator sub-systems for a single game:
///   - KDF (K_view, K_chat_spec_dir)
///   - Topology (single-hop, issuing peer only)
///   - Capacity caps
///   - Auth / rate-limit
///   - Heartbeat / seat reclaim
///   - Chat (token bucket, size cap, slow mode, mute, sanitisation)
///   - Perf isolation (frame budget, LIFO eviction, decode rate)
library;

import 'dart:typed_data';

import 'spectator_auth.dart';
import 'spectator_capacity.dart';
import 'spectator_chat.dart';
import 'spectator_heartbeat.dart';
import 'spectator_kdf.dart';
import 'spectator_perf.dart';
import 'spectator_topology.dart';

/// Result of a spectator join attempt.
class SpectatorJoinResult {
  /// Null on success; error code string on failure.
  final String? error;

  /// The derived K_view key (only populated on success).
  final Uint8List? kView;

  const SpectatorJoinResult._({this.error, this.kView});

  factory SpectatorJoinResult.success(Uint8List kView) =>
      SpectatorJoinResult._(kView: kView);
  factory SpectatorJoinResult.failure(String error) =>
      SpectatorJoinResult._(error: error);

  bool get isSuccess => error == null;
}

/// Umbrella spectator session for an issuing peer.
class SpectatorSession {
  final Uint8List sessionMaster;
  final Uint8List issuingPeerPubKey;

  late final SpectatorCapacityManager _capacity;
  late final SpectatorAuthPolicy _auth;
  late final SpectatorJoinRateLimit _rateLimit;
  late final SpectatorHeartbeatManager _heartbeat;
  late final SpectatorTopology _topology;
  late final ChatModerationState _chatState;
  late final SpectatorFrameBudget _frameBudget;
  late final SpectatorLifoEvictionQueue _lifoQueue;
  late final AccountSpectatorQuota _quota;

  // K_view keyed by spectator pub-key hex
  final Map<String, Uint8List> _kViews = {};

  SpectatorSession({
    required this.sessionMaster,
    required this.issuingPeerPubKey,
    int? perGameCap,
  }) {
    _capacity = SpectatorCapacityManager(cap: perGameCap);
    _auth = SpectatorAuthPolicy();
    _rateLimit = SpectatorJoinRateLimit();
    _heartbeat = SpectatorHeartbeatManager();
    _topology = SpectatorTopology(localRole: PeerRole.issuing);
    _chatState = ChatModerationState();
    _frameBudget = SpectatorFrameBudget();
    _lifoQueue = SpectatorLifoEvictionQueue();
    _quota = AccountSpectatorQuota();
  }

  /// Handle a spectator join request.
  SpectatorJoinResult handleJoin({
    required SpectatorAuthRequest authRequest,
    required String accountId,
    required int nowMs,
    Uint8List? salt,
  }) {
    // 1. Authentication check.
    final authErr = _auth.validate(authRequest);
    if (authErr != null) return SpectatorJoinResult.failure(authErr);

    // 2. Rate limit.
    final rateErr = _rateLimit.attempt(accountId, nowMs);
    if (rateErr != null) return SpectatorJoinResult.failure(rateErr);

    // 3. Capacity.
    final capResult = _capacity.admit(authRequest.devicePubKey!);
    if (capResult == kSpectatorCapacityFull) {
      return SpectatorJoinResult.failure(kSpectatorCapacityFull);
    }

    // 4. Derive K_view.
    final kView = deriveKView(
      sessionMaster: sessionMaster,
      spectatorPubKey: authRequest.devicePubKey!,
      salt: salt,
    );
    final hex = authRequest.devicePubKey!
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    _kViews[hex] = kView;

    // 5. Register heartbeat tracker.
    _heartbeat.registerSpectator(
      spectatorPubKey: authRequest.devicePubKey!,
      nowMs: nowMs,
    );

    // 6. Register in topology + LIFO queue.
    _topology.addSpectator(SpectatorChannel(
      spectatorPubKey: authRequest.devicePubKey!,
    ));
    _lifoQueue.onSpectatorJoined(hex);

    return SpectatorJoinResult.success(kView);
  }

  /// Handle a heartbeat from a spectator.
  void onHeartbeat(Uint8List spectatorPubKey, int nowMs) {
    _heartbeat.onHeartbeat(spectatorPubKey: spectatorPubKey, nowMs: nowMs);
  }

  /// Run heartbeat eviction check. Returns list of evicted pub-keys.
  List<Uint8List> checkEvictions(int nowMs) {
    return _heartbeat.evictionCandidates(nowMs);
  }

  /// Retrieve K_view for a spectator (host use only).
  Uint8List? kViewFor(Uint8List spectatorPubKey) {
    final hex =
        spectatorPubKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return _kViews[hex];
  }

  int get seatedCount => _capacity.seatedCount;
  ChatModerationState get chatState => _chatState;
  SpectatorFrameBudget get frameBudget => _frameBudget;
  SpectatorLifoEvictionQueue get lifoQueue => _lifoQueue;
}
