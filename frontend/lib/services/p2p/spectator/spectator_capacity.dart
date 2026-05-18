// ignore_for_file: constant_identifier_names

/// Capacity caps for spectator mode (§7.8.2).
///
/// - Default per-game cap: 50 spectators.
/// - Hard ceiling: 200.
/// - Lower-of-the-two wins (player A cap overrides player B if A is lower).
/// - Per-issuing-peer-account cap across concurrent games: 100.
/// - Over-cap → SPECTATOR_CAPACITY_FULL.
/// - Waitlist: FIFO, max depth 50, expires when game ends.
library;

import 'dart:typed_data';

/// Error codes for spectator capacity events (F-SPEC-001, §10.5).
const String kSpectatorCapacityFull = 'SPECTATOR_CAPACITY_FULL';

/// Manages per-game spectator capacity and waitlist.
class SpectatorCapacityManager {
  static const int defaultCap = 50;
  static const int hardCeiling = 200;
  static const int waitlistMaxDepth = 50;

  /// The effective per-game cap (≤ [hardCeiling]).
  final int effectiveCap;

  final List<Uint8List> _seated = [];
  final List<Uint8List> _waitlist = [];

  SpectatorCapacityManager({int? cap})
      : effectiveCap = _clamp(cap ?? defaultCap);

  static int _clamp(int v) => v.clamp(1, hardCeiling);

  /// Combine two players' requested caps: lower-of-the-two wins.
  static int lowerOf(int capA, int capB) => _clamp(capA < capB ? capA : capB);

  int get seatedCount => _seated.length;
  int get waitlistDepth => _waitlist.length;

  /// True when at or above [effectiveCap].
  bool get isFull => _seated.length >= effectiveCap;

  /// Attempt to seat a spectator.
  ///
  /// Returns `null` on success.
  /// Returns [kSpectatorCapacityFull] when full and waitlist is also full.
  /// Returns 'WAITLISTED' when full but queued successfully.
  String? admit(Uint8List spectatorPubKey) {
    if (!isFull) {
      _seated.add(spectatorPubKey);
      return null; // seated
    }
    // Capacity full — try waitlist.
    if (_waitlist.length < waitlistMaxDepth) {
      _waitlist.add(spectatorPubKey);
      return 'WAITLISTED';
    }
    return kSpectatorCapacityFull;
  }

  /// Release a seat (disconnect / eviction). Promotes next from waitlist.
  void release(Uint8List spectatorPubKey) {
    _seated.removeWhere((k) => _eq(k, spectatorPubKey));
    // Promote waitlist head if capacity allows.
    if (_waitlist.isNotEmpty && !isFull) {
      final next = _waitlist.removeAt(0);
      _seated.add(next);
    }
  }

  /// Expire all waitlist entries (called when game ends).
  void expireWaitlist() => _waitlist.clear();

  static bool _eq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Tracks global spectator count across all concurrent games for one account.
///
/// Per-issuing-peer-account limit: 100.
class AccountSpectatorQuota {
  static const int perAccountCap = 100;

  int _total = 0;

  int get totalSpectators => _total;

  bool get isAtLimit => _total >= perAccountCap;

  void addSpectators(int n) => _total += n;
  void removeSpectators(int n) => _total = (_total - n).clamp(0, perAccountCap * 10);
}
