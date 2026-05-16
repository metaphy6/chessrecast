/// App lifecycle policy for P2P sessions.
///
/// §4.3 — Android requires a foreground service to keep the WebRTC
/// peer-connection alive while the app is in the background.  iOS
/// relies on push-based wakeups (APNs) and must NOT use a VoIP
/// background mode for non-voice content.
library;

enum AppPlatform { android, iOS }

enum SuspensionStrategy { gracefulClose, foregroundService }

enum ReestablishmentMethod { pushWakeup, foregroundService }

class AppLifecyclePolicy {
  final AppPlatform platform;

  /// P95 latency budget (ms) from push receipt to first DataChannel message.
  static const int pushWakeupP95BudgetMs = 5000;

  const AppLifecyclePolicy({required this.platform});

  /// Whether this platform requires an Android foreground service to keep
  /// the P2P connection alive during background play.
  bool requiresForegroundService({required bool gameActive}) =>
      platform == AppPlatform.android && gameActive;

  /// Strategy taken when the app moves to the background.
  SuspensionStrategy get suspensionStrategy => switch (platform) {
        AppPlatform.android => SuspensionStrategy.foregroundService,
        AppPlatform.iOS => SuspensionStrategy.gracefulClose,
      };

  /// Method used to re-establish the P2P session after suspension.
  ReestablishmentMethod get reestablishmentMethod => switch (platform) {
        AppPlatform.android => ReestablishmentMethod.foregroundService,
        AppPlatform.iOS => ReestablishmentMethod.pushWakeup,
      };

  /// iOS does not use VoIP background mode (reserved for actual voice calls).
  bool get usesVoipBackground => false;
}

// ── iOS NSE (Notification Service Extension) models ─────────────────────────

enum PreWarmStrategy { bestEffort }

/// Lightweight push payload used to wake the iOS NSE.
/// Contains only a redeem-once hint token; no plaintext game data.
class PushWakeupPayload {
  final String sessionHint;

  const PushWakeupPayload({required this.sessionHint});

  /// Push payloads never contain game data (security requirement).
  bool get containsGameData => false;

  /// Every session hint is a one-time-use opaque token.
  bool get isRedeemOnce => true;

  /// Serialise to the APNs JSON envelope expected by the iOS NSE.
  Map<String, dynamic> toApnsJson() => {
        'aps': {'content-available': 1},
        'token': sessionHint,
      };
}

class NsePlatformPolicy {
  /// The NSE pre-warm is best-effort (not blocking): if the NSE times out
  /// before the main app launches, the main app performs ICE gather itself.
  static const PreWarmStrategy preWarmStrategy = PreWarmStrategy.bestEffort;

  const NsePlatformPolicy._();
}
