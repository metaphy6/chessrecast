/// SCTP backpressure controller.
///
/// §4.2 — The chess DataChannel must never block the UI thread.
/// When the outbound SCTP send buffer grows beyond [thresholdBytes] for
/// more than [sustainedMs] milliseconds, the controller sets [shouldDrop]
/// and clients must discard the pending message.
library;

/// Controls whether outgoing DataChannel messages should be dropped to
/// prevent unbounded SCTP buffer growth.
class BackpressureController {
  /// Queue size threshold above which the "sustained timer" starts.
  static const int thresholdBytes = 256 * 1024; // 256 KiB

  /// Duration in milliseconds for which the queue must exceed [thresholdBytes]
  /// before [shouldDrop] becomes true.
  static const int sustainedMs = 5000; // 5 s

  bool _shouldDrop = false;
  String? _dropReason;

  /// The timestamp (ms) when the queue first exceeded [thresholdBytes].
  int? _thresholdCrossedAtMs;

  /// Whether the next outgoing message should be dropped.
  bool get shouldDrop => _shouldDrop;

  /// Human-readable reason; non-null when [shouldDrop] is true.
  String? get dropReason => _dropReason;

  /// Update backpressure state.
  ///
  /// [queueBytes] — current SCTP send-buffer occupancy.
  /// [timestampMs] — monotonic clock value in milliseconds.
  void onQueueUpdate({required int queueBytes, required int timestampMs}) {
    if (queueBytes < thresholdBytes) {
      // Queue has cleared; reset state.
      _thresholdCrossedAtMs = null;
      _shouldDrop = false;
      _dropReason = null;
      return;
    }

    // Queue is above threshold.
    _thresholdCrossedAtMs ??= timestampMs;

    final sustainedDuration = timestampMs - _thresholdCrossedAtMs!;
    if (sustainedDuration >= sustainedMs) {
      _shouldDrop = true;
      _dropReason = 'BACKPRESSURE_DROP';
    }
  }
}
