// §4.1 TURN credential model (client-side).
//
// TURN credentials are minted by the signaling server via HMAC-SHA256 and
// are valid for exactly [serverTtl] = 5 minutes.  The client should refresh
// when [TurnCredential.nearExpired] is true (60 s before expiry).

/// How long the server mints TURN credentials for (must match turn.go TTL).
const Duration _kRefreshBuffer = Duration(seconds: 60);

/// A single short-lived TURN username/password pair.
class TurnCredential {
  /// TURN username in coturn format: `<unix_ts>:<base_user>`.
  final String username;

  /// HMAC-SHA256 password.
  final String credential;

  /// When this credential expires on the server.
  final DateTime expiresAt;

  const TurnCredential({
    required this.username,
    required this.credential,
    required this.expiresAt,
  });

  /// True when the current wall-clock is past [expiresAt].
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// True when fewer than [_kRefreshBuffer] remain before expiry.
  bool get nearExpired =>
      DateTime.now().isAfter(expiresAt.subtract(_kRefreshBuffer));

  /// Parse a JSON response from `GET /v1/turn/creds`.
  factory TurnCredential.fromServerResponse(Map<String, dynamic> json) {
    final username = json['username'] as String;
    final credential = json['credential'] as String;
    final ttlSeconds = (json['ttl'] as num).toInt();
    // Derive expiry from ttl_seconds so we are independent of the server's
    // local clock (avoids clock-skew issues).
    final expiresAt = DateTime.now().add(Duration(seconds: ttlSeconds));
    return TurnCredential(
      username: username,
      credential: credential,
      expiresAt: expiresAt,
    );
  }
}

/// Client-side service managing short-lived TURN credentials.
///
/// Usage:
/// ```dart
/// final svc = TurnCredentialService(fetchFn: mySignalingClient.fetchTurnCreds);
/// final cred = await svc.get();
/// final ice = IceConfig.build(
///   turnUsername: cred.username, turnCredential: cred.credential);
/// ```
class TurnCredentialService {
  /// Server-side TTL for TURN credentials (5 minutes, per §4.1).
  static const Duration serverTtl = Duration(minutes: 5);

  final Future<TurnCredential> Function() _fetchFn;
  TurnCredential? _cached;

  TurnCredentialService({required Future<TurnCredential> Function() fetchFn})
      : _fetchFn = fetchFn;

  /// Returns a valid [TurnCredential], refreshing from the server if needed.
  Future<TurnCredential> get() async {
    if (_cached == null || _cached!.nearExpired) {
      _cached = await _fetchFn();
    }
    return _cached!;
  }

  /// Force-invalidate any cached credential.
  void invalidate() => _cached = null;
}
