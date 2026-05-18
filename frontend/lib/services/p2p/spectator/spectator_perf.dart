// ignore_for_file: constant_identifier_names

/// Spectator performance isolation (§7.10).
///
/// Structural guarantees:
///   - SCTP stream 1 (chess+clock) always has high priority.
///   - SCTP stream 7 (chat+roster) has low priority.
///   - Spectator UI work ≤ 2 ms / frame on issuing peer's UI isolate.
///   - Excess work offloaded to p2p isolate.
///   - Frame budget exceeded for ≥ 3 s → LIFO eviction of spectators.
///   - Spectator decode rate: ≤ 30 msg/s; overflow → CHAT_RECEIVER_OVERFLOW.
library;

// ─── SCTP stream priority §7.10.1 ────────────────────────────────────────────

const String kChatReceiverOverflow = 'CHAT_RECEIVER_OVERFLOW'; // F-CHAT-008
const String kSpectatorShedForPerf = 'SPECTATOR_SHED_FOR_PERF'; // F-SPEC-009
const String kSpectatorRelayUnavailable = 'SPECTATOR_RELAY_UNAVAILABLE'; // F-SPEC-010

/// SCTP stream priority constants.
class SctpStreamPriority {
  SctpStreamPriority._();

  /// Chess moves + clock + back-fill stream (high priority).
  static const int chessStream = 1;
  static const String chessPriority = 'high';

  /// Chat + roster stream (low priority).
  static const int chatStream = 7;
  static const String chatPriority = 'low';
}

// ─── Frame budget §7.10.2 ────────────────────────────────────────────────────

/// Tracks per-frame budget for spectator work on the UI isolate.
class SpectatorFrameBudget {
  static const double budgetMs = 2.0; // ≤ 2 ms / frame
  static const int excessThresholdMs = 3000; // 3 s continuous excess

  int? _budgetExceededSinceMs;

  /// Record a frame tick with [workMs] of spectator work performed.
  ///
  /// [nowMs] — monotonic clock in ms.
  /// Returns [kSpectatorShedForPerf] if LIFO eviction should begin.
  String? onFrameTick({required double workMs, required int nowMs}) {
    if (workMs <= budgetMs) {
      _budgetExceededSinceMs = null;
      return null;
    }
    _budgetExceededSinceMs ??= nowMs;
    final elapsed = nowMs - _budgetExceededSinceMs!;
    if (elapsed >= excessThresholdMs) {
      return kSpectatorShedForPerf;
    }
    return null;
  }
}

// ─── LIFO eviction §7.10.2 ───────────────────────────────────────────────────

/// Manages LIFO eviction order for spectators.
///
/// "Most-recent join first" order.
class SpectatorLifoEvictionQueue {
  final List<String> _joinOrder = []; // pub-key hexes, FIFO join order

  void onSpectatorJoined(String pubKeyHex) {
    _joinOrder.add(pubKeyHex);
  }

  void onSpectatorLeft(String pubKeyHex) {
    _joinOrder.remove(pubKeyHex);
  }

  /// Returns the pub-key hex of the spectator to evict next (most recent join).
  String? nextEvictionCandidate() {
    if (_joinOrder.isEmpty) return null;
    return _joinOrder.last;
  }

  /// Evict the most-recent spectator and return their pub-key hex.
  String? evictOne() {
    if (_joinOrder.isEmpty) return null;
    return _joinOrder.removeLast();
  }

  int get count => _joinOrder.length;
}

// ─── Decode rate limiter §7.10.4 ─────────────────────────────────────────────

/// Limits spectator-side chat decode rate to 30 msg/s.
///
/// Excess messages buffer up to 100, then [kChatReceiverOverflow].
class SpectatorDecodeRateLimiter {
  static const int maxMsgPerSec = 30;
  static const int overflowBufferMax = 100;

  final List<int> _decodeTimestamps = [];
  int _buffered = 0;

  /// Attempt to decode a message at [nowMs].
  ///
  /// Returns `null` on success, [kChatReceiverOverflow] when both the rate
  /// limit and the overflow buffer are full.
  String? tryDecode(int nowMs) {
    _decodeTimestamps.removeWhere((t) => nowMs - t >= 1000);

    if (_decodeTimestamps.length < maxMsgPerSec) {
      _decodeTimestamps.add(nowMs);
      return null;
    }

    // Rate limited: try overflow buffer.
    if (_buffered < overflowBufferMax) {
      _buffered++;
      return null;
    }
    return kChatReceiverOverflow;
  }

  void drainBuffer() => _buffered = 0;
}

// ─── Backpressure fan-out §7.10.7 ────────────────────────────────────────────

const String kSpectatorBackpressureStall =
    'SPECTATOR_BACKPRESSURE_STALL'; // F-SPEC-014

/// Per-spectator send-side backpressure state.
class SpectatorBackpressureState {
  static const int highWaterMarkMs = 2000; // 2 s
  static const int evictionMs = 10000; // 10 s

  int? _stallStartMs;

  /// Called when the SCTP send buffer is above high-water mark.
  ///
  /// Returns [kSpectatorShedForPerf] when eviction threshold reached,
  /// [kSpectatorBackpressureStall] when pausing chat fan-out,
  /// null when below high-water mark.
  String? onBackpressureTick({required bool aboveHighWater, required int nowMs}) {
    if (!aboveHighWater) {
      _stallStartMs = null;
      return null;
    }
    _stallStartMs ??= nowMs;
    final elapsed = nowMs - _stallStartMs!;
    if (elapsed >= evictionMs) return kSpectatorShedForPerf;
    if (elapsed >= highWaterMarkMs) return kSpectatorBackpressureStall;
    return null;
  }
}
