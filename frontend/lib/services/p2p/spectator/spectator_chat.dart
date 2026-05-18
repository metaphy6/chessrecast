// ignore_for_file: constant_identifier_names

/// Spectator chat sub-system (§7.9).
///
/// Token bucket: sustained 1 msg / 3 s, burst 3.
/// Size cap: ≤ 280 Unicode scalars, ≤ 512 UTF-8 bytes.
/// Slow mode: host-configurable minimum send interval.
/// Global mute: host one-tap, session-scoped.
library;

import 'dart:convert';
import 'dart:typed_data';

// ─── Error / status codes ─────────────────────────────────────────────────────

const String kChatRateLimited = 'CHAT_RATE_LIMITED'; // F-CHAT-004
const String kChatMessageOversized = 'CHAT_MESSAGE_OVERSIZED'; // F-CHAT-005
const String kChatAutoThrottledClockPressure =
    'CHAT_AUTO_THROTTLED_CLOCK_PRESSURE'; // F-CHAT-007
const String kChatTournamentLocked = 'CHAT_TOURNAMENT_LOCKED'; // F-CHAT-010

// ─── Token bucket §7.9.2 ──────────────────────────────────────────────────────

/// Sender token bucket.
///
/// Sustained rate: 1 message every 3 s.
/// Burst capacity: 3 tokens.
/// State keyed by (account pubkey, game id); NOT reset on rejoin (§7.9.2).
class ChatTokenBucket {
  static const double maxTokens = 3.0;
  static const double refillRatePerMs = 1.0 / 3000.0; // 1 token / 3 s

  double _tokens;
  int _lastRefillMs;

  ChatTokenBucket({required int nowMs})
      : _tokens = maxTokens,
        _lastRefillMs = nowMs;

  /// Attempt to consume one token at [nowMs].
  ///
  /// Returns `null` on success, [kChatRateLimited] if no token available.
  String? consume(int nowMs) {
    _refill(nowMs);
    if (_tokens < 1.0) return kChatRateLimited;
    _tokens -= 1.0;
    return null;
  }

  /// Apply a –3 token penalty (e.g. oversize message caught server-side).
  void applyOversizePenalty(int nowMs) {
    _refill(nowMs);
    _tokens = (_tokens - 3.0).clamp(-3.0, maxTokens);
  }

  /// Current token count (for UI countdown).
  double get tokens => _tokens;

  void _refill(int nowMs) {
    final elapsedMs = nowMs - _lastRefillMs;
    if (elapsedMs > 0) {
      _tokens =
          (_tokens + elapsedMs * refillRatePerMs).clamp(0.0, maxTokens);
      _lastRefillMs = nowMs;
    }
  }
}

/// Manages token buckets keyed by (accountPubKeyHex, gameId).
/// State PERSISTS across rejoin (anti-evasion per §7.9.2).
class ChatTokenBucketRegistry {
  final Map<String, ChatTokenBucket> _buckets = {};

  String _key(String accountPubKeyHex, String gameId) =>
      '$accountPubKeyHex:$gameId';

  ChatTokenBucket getOrCreate(
      String accountPubKeyHex, String gameId, int nowMs) {
    return _buckets.putIfAbsent(
      _key(accountPubKeyHex, gameId),
      () => ChatTokenBucket(nowMs: nowMs),
    );
  }

  /// Attempt to send a message. Returns null on success, error code on rejection.
  String? tryConsume(
      String accountPubKeyHex, String gameId, int nowMs) {
    return getOrCreate(accountPubKeyHex, gameId, nowMs).consume(nowMs);
  }
}

// ─── Size cap §7.9.3 ──────────────────────────────────────────────────────────

/// Hard chat size cap.
///
/// Post-decrypt, post-NFC-normalisation:
///   ≤ 280 Unicode scalars, ≤ 512 UTF-8 bytes.
class ChatSizeCap {
  static const int maxScalars = 280;
  static const int maxUtf8Bytes = 512;

  /// Validate [text] (post NFC-normalisation).
  ///
  /// Returns null on success, [kChatMessageOversized] on failure.
  static String? validate(String text) {
    // Count Unicode scalar values (Dart String runes).
    if (text.runes.length > maxScalars) return kChatMessageOversized;
    final bytes = utf8.encode(text);
    if (bytes.length > maxUtf8Bytes) return kChatMessageOversized;
    return null;
  }
}

// ─── Slow mode & global mute §7.9.4 ──────────────────────────────────────────

/// Slow-mode intervals exposed in the host UI.
enum SlowModeInterval {
  off, // 0 s (no slow mode)
  fiveSec, // 5 s (default)
  thirtySec, // 30 s
  twoMin, // 120 s
}

extension SlowModeIntervalSeconds on SlowModeInterval {
  int get seconds {
    switch (this) {
      case SlowModeInterval.off:
        return 0;
      case SlowModeInterval.fiveSec:
        return 5;
      case SlowModeInterval.thirtySec:
        return 30;
      case SlowModeInterval.twoMin:
        return 120;
    }
  }
}

/// Manages slow mode and global mute state for a session.
class ChatModerationState {
  SlowModeInterval _slowMode = SlowModeInterval.fiveSec;
  bool _globalMute = false;

  // Auto-throttle clock pressure state (§7.9.6).
  bool _clockPressureMute = false;
  bool _clockPressureSlow30 = false;

  SlowModeInterval get effectiveSlowMode {
    // Auto-throttle overrides: clock < 30 s → slow ≥ 30 s.
    if (_clockPressureMute) return SlowModeInterval.thirtySec;
    if (_clockPressureSlow30) {
      // Force minimum 30 s.
      final hostSec = _slowMode.seconds;
      if (hostSec < 30) return SlowModeInterval.thirtySec;
    }
    return _slowMode;
  }

  bool get isGloballyMuted => _globalMute || _clockPressureMute;

  /// Host sets slow mode. Does NOT refund spent tokens (§7.9.4).
  void setSlowMode(SlowModeInterval mode) => _slowMode = mode;

  /// Host toggles global mute.
  void setGlobalMute({required bool muted}) => _globalMute = muted;

  /// Called when any player's clock drops below a threshold (§7.9.6).
  void onClockUpdate(int minClockRemainingMs) {
    if (minClockRemainingMs < 10000) {
      // < 10 s → mute
      _clockPressureMute = true;
      _clockPressureSlow30 = false;
    } else if (minClockRemainingMs < 30000) {
      // < 30 s → slow ≥ 30 s
      _clockPressureMute = false;
      _clockPressureSlow30 = true;
    } else {
      _clockPressureMute = false;
      _clockPressureSlow30 = false;
    }
  }

  /// Called after a move is played (releases clock-pressure mute if clock ≥ 10 s).
  void onMovePlayed(int minClockRemainingMs) {
    onClockUpdate(minClockRemainingMs);
  }
}

// ─── Tournament / rated lockdown §7.9.8 ──────────────────────────────────────

/// Chat policy for a game session.
class GameChatPolicy {
  final bool isTournament;
  final bool isRated;

  /// Whether chat is explicitly unlocked by the issuing peer.
  final bool hostOptedIn;

  const GameChatPolicy({
    required this.isTournament,
    required this.isRated,
    required this.hostOptedIn,
  });

  /// Returns [kChatTournamentLocked] when the game is tournament/rated
  /// and the host has not explicitly opted in.
  String? validatePolicy() {
    if ((isTournament || isRated) && !hostOptedIn) {
      return kChatTournamentLocked;
    }
    return null;
  }
}
