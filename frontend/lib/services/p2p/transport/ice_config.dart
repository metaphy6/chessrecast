// §4.1 ICE / STUN / TURN server configuration.
//
// Topology (per P2P_ROADMAP §4.1):
//   - 1 STUN server  (self-hosted, same host as signaling)
//   - 2 TURN servers: UDP on :3478 and TCP on :443 (DPI-resistant fallback)
//   - Optional TURNS (TURN-over-TLS) on :5349 / :443 (§4.10)
//
// Credentials are issued short-lived (5 min) by the signaling server via
// HMAC-SHA256 (§3.x /v1/turn/creds endpoint); the static fallback is
// intentionally empty so misconfigured deployments fail closed.

const String _kStunHost = 'stun.chessrecast.app';
const String _kTurnHost = 'turn.chessrecast.app';
const int _kStunPort = 3478;
const int _kTurnUdpPort = 3478;
const int _kTurnTcpPort = 443;
const int _kTurnsTlsPort = 5349;

/// A single ICE server entry (STUN or TURN / TURNS).
class IceServer {
  /// Full URL, e.g. `stun:stun.chessrecast.app:3478` or
  /// `turn:turn.chessrecast.app:443?transport=tcp`.
  final String url;

  /// TURN username (null for STUN).
  final String? username;

  /// TURN credential (null for STUN).
  final String? credential;

  const IceServer({
    required this.url,
    this.username,
    this.credential,
  });

  bool get isStun => url.startsWith('stun:');
  bool get isTurn => url.startsWith('turn:');
  bool get isTurns => url.startsWith('turns:');

  @override
  String toString() => 'IceServer($url)';
}

/// ICE configuration produced by [IceConfig.build] or [IceConfig.buildIpv6].
///
/// Always contains:
///   - [stunCount] == 1
///   - [turnCount] == 2 (UDP + TCP/443)
///   - [turnsCount] >= 2 when [IceConfig.build] is called with [includeTurns]=true
///   - [pathMtuClamp] == 1280 for IPv6-only paths (NAT64/DNS64, §4.1)
class IceConfig {
  final List<IceServer> servers;

  /// Path MTU clamp in bytes (1280 for IPv6-only; null for standard IPv4/dual).
  final int? pathMtuClamp;

  const IceConfig({required this.servers, this.pathMtuClamp});

  // ─── Computed properties ────────────────────────────────────────────────

  int get stunCount => servers.where((s) => s.isStun).length;
  int get turnCount => servers.where((s) => s.isTurn).length;
  int get turnsCount => servers.where((s) => s.isTurns).length;

  bool get hasUdpTurn =>
      servers.any((s) => s.isTurn && s.url.contains('transport=udp'));

  bool get hasTcpTurn443 =>
      servers.any((s) =>
          s.isTurn &&
          s.url.contains('transport=tcp') &&
          s.url.contains(':$_kTurnTcpPort'));

  // ─── Factory ────────────────────────────────────────────────────────────

  /// Build an [IceConfig] with the canonical server list.
  ///
  /// [turnUsername] and [turnCredential] are short-lived HMAC credentials
  /// minted by the signaling server.  When omitted the TURN servers are
  /// still listed (useful for unit tests that only validate topology).
  ///
  /// Set [includeTurns] to add TURNS-over-TLS entries (§4.10).
  factory IceConfig.build({
    String? turnUsername,
    String? turnCredential,
    bool includeTurns = false,
  }) {
    final servers = <IceServer>[
      // ── STUN (1 server) ──────────────────────────────────────────────
      const IceServer(url: 'stun:$_kStunHost:$_kStunPort'),

      // ── TURN UDP (primary) ───────────────────────────────────────────
      IceServer(
        url: 'turn:$_kTurnHost:$_kTurnUdpPort?transport=udp',
        username: turnUsername,
        credential: turnCredential,
      ),

      // ── TURN TCP/443 (restrictive-network fallback) ──────────────────
      IceServer(
        url: 'turn:$_kTurnHost:$_kTurnTcpPort?transport=tcp',
        username: turnUsername,
        credential: turnCredential,
      ),
    ];

    if (includeTurns) {
      // ── TURNS TLS/5349 (DPI-resistance, §4.10) ──────────────────────
      servers.add(IceServer(
        url: 'turns:$_kTurnHost:$_kTurnsTlsPort?transport=tcp',
        username: turnUsername,
        credential: turnCredential,
      ));
      // ── TURNS TLS/443 (SNI-shared with signaling HTTPS) ─────────────
      servers.add(IceServer(
        url: 'turns:$_kTurnHost:$_kTurnTcpPort?transport=tcp',
        username: turnUsername,
        credential: turnCredential,
      ));
    }

    return IceConfig(servers: servers);
  }

  /// Build an [IceConfig] for IPv6-only carriers (e.g. NAT64/DNS64 paths).
  ///
  /// Sets [pathMtuClamp] to 1280 (the IPv6 minimum MTU) per RFC 8200 §5.
  /// Server hostnames are identical — DNS returns AAAA records on
  /// IPv6-only networks; no bracket-notation literals are needed.
  factory IceConfig.buildIpv6({
    String? turnUsername,
    String? turnCredential,
    bool includeTurns = false,
  }) {
    final base = IceConfig.build(
      turnUsername: turnUsername,
      turnCredential: turnCredential,
      includeTurns: includeTurns,
    );
    return IceConfig(servers: base.servers, pathMtuClamp: 1280);
  }

  @override
  String toString() =>
      'IceConfig(stun=$stunCount, turn=$turnCount, turns=$turnsCount, mtu=$pathMtuClamp)';
}
