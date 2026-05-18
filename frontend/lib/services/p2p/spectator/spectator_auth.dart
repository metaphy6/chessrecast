// ignore_for_file: constant_identifier_names

/// Spectator authentication policy (§7.8.3).
///
/// Anonymous viewers are forbidden in v1 (OQ-41 default).
/// Every spectator must present a registered Ed25519 device pubkey.
/// Unauthenticated joins → SPECTATOR_AUTH_REQUIRED (F-SPEC-003).
library;

import 'dart:typed_data';

/// Error code when an anonymous spectator attempts to join.
const String kSpectatorAuthRequired = 'SPECTATOR_AUTH_REQUIRED';

/// Represents a spectator authentication attempt.
class SpectatorAuthRequest {
  /// The spectator's Ed25519 device public key (32 bytes), or null if anonymous.
  final Uint8List? devicePubKey;

  /// A registered account identifier (may equal pubkey hex in v1 scheme).
  final String? accountId;

  const SpectatorAuthRequest({this.devicePubKey, this.accountId});

  /// True iff the spectator has provided a non-null public key.
  bool get isAuthenticated =>
      devicePubKey != null && devicePubKey!.length == 32;
}

/// Validates spectator join requests against the v1 authentication policy.
class SpectatorAuthPolicy {
  /// Validate [request].
  ///
  /// Returns `null` if the request is valid.
  /// Returns [kSpectatorAuthRequired] if the spectator is anonymous.
  String? validate(SpectatorAuthRequest request) {
    if (!request.isAuthenticated) return kSpectatorAuthRequired;
    return null;
  }
}

/// Per-account spectator-join rate limit (§7.8.4).
///
/// Limits: ≤ 6 joins / minute, ≤ 60 / hour per account.
/// Excess → SPECTATOR_JOIN_RATE_LIMITED (F-SPEC-004).
const String kSpectatorJoinRateLimited = 'SPECTATOR_JOIN_RATE_LIMITED';

class SpectatorJoinRateLimit {
  static const int maxPerMinute = 6;
  static const int maxPerHour = 60;

  // Key: accountId → list of join timestamps (ms)
  final Map<String, List<int>> _timestamps = {};

  /// Attempt to record a join for [accountId] at [nowMs] (monotonic ms).
  ///
  /// Returns `null` on success, [kSpectatorJoinRateLimited] if over limit.
  String? attempt(String accountId, int nowMs) {
    final ts = _timestamps.putIfAbsent(accountId, () => []);

    // Prune entries older than 1 hour.
    ts.removeWhere((t) => nowMs - t > 3600000);

    // Count last minute.
    final lastMinute = ts.where((t) => nowMs - t < 60000).length;
    if (lastMinute >= maxPerMinute) return kSpectatorJoinRateLimited;

    // Count last hour (already pruned above).
    if (ts.length >= maxPerHour) return kSpectatorJoinRateLimited;

    ts.add(nowMs);
    return null;
  }
}
