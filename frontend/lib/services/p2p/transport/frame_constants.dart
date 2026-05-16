/// Frame-size constants for SCTP DataChannel messages.
///
/// §4.2 — WebRTC DataChannel messages are SCTP datagrams.
/// Browsers and native stacks impose different SCTP message-size limits.
/// To remain universally compatible we cap every outgoing frame at
/// [maxFrameSizeBytes].
///
/// BYE/goodbye frames that are larger than [byeFragmentThresholdBytes] must
/// be fragmented before transmission.
library;

class FrameConstants {
  const FrameConstants._();

  /// Hard upper bound on a single DataChannel message payload (bytes).
  /// 16 KiB — safe across all browser / native SCTP stacks we support.
  static const int maxFrameSizeBytes = 16 * 1024; // 16 KiB

  /// BYE frames larger than this are fragmented to avoid head-of-line
  /// blocking on the chess channel.
  static const int byeFragmentThresholdBytes = 12 * 1024; // 12 KiB

  /// Returns true if [payloadLength] is within the frame size limit.
  static bool validateSize(int payloadLength) =>
      payloadLength <= maxFrameSizeBytes;
}
