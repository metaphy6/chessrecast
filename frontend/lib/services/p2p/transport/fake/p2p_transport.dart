/// Abstract P2P transport interface.
///
/// Used by fake transports (§5.5) and future production WebRTC transports.
/// All methods are channel-aware (`'chess'`, `'clock'`, `'chat'`).
library;

import 'dart:typed_data';

/// Bidirectional message transport for a single P2P channel pair.
///
/// Implementors: [FakeTransport], [JitterTransport], [LossyTransport],
/// [ReorderingTransport].
abstract interface class P2PTransport {
  /// Send [bytes] on the named [channel].
  ///
  /// Valid channel names: `'chess'`, `'clock'`, `'chat'`.
  Future<void> send(String channel, Uint8List bytes);

  /// Stream of `(channel, bytes)` tuples received from the remote peer.
  ///
  /// Each event is a positional record `(String channel, Uint8List bytes)`.
  Stream<(String, Uint8List)> get incoming;

  /// Close the transport and release all resources.
  Future<void> close();
}
