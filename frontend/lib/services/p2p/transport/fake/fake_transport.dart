/// §5.5 FakeTransport — baseline in-memory bidirectional pipe.
///
/// Zero loss, zero jitter, FIFO delivery. Establishes the "no network is in
/// the picture" reference behaviour for L5 (synthetic-network integration)
/// tests.
///
/// Create a connected pair via [FakeTransport.pair]. Each side of the pair
/// implements [P2PTransport]; calling [send] on one side delivers bytes to
/// the [incoming] stream of the other.
library;

import 'dart:async';
import 'dart:typed_data';

import 'p2p_transport.dart';

/// Baseline in-memory transport — zero loss, zero jitter, FIFO.
class FakeTransport implements P2PTransport {
  // sync: true — events are delivered synchronously into the listener when
  // add() is called.  This is the correct behaviour for an in-process fake
  // transport: the caller "sends" a frame and the receiver "gets" it
  // immediately, with no microtask delay that could race test assertions.
  final StreamController<(String, Uint8List)> _controller =
      StreamController(sync: true);

  FakeTransport? _peer;
  bool _closed = false;

  FakeTransport._();

  /// Creates a connected pair of [FakeTransport] instances.
  ///
  /// Sending on `a` delivers bytes to `b.incoming` and vice-versa.
  static (FakeTransport, FakeTransport) pair() {
    final a = FakeTransport._();
    final b = FakeTransport._();
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  /// Throws [StateError] synchronously if closed (allows throwsStateError matcher).
  @override
  Future<void> send(String channel, Uint8List bytes) {
    if (_closed) throw StateError('FakeTransport is closed');
    final peer = _peer!;
    if (!peer._closed) {
      peer._controller.add((channel, bytes));
    }
    return Future.value();
  }

  @override
  Stream<(String, Uint8List)> get incoming => _controller.stream;

  /// Sets [_closed] synchronously and fire-and-forgets [_controller.close()].
  ///
  /// [StreamController.close] returns a Future that only resolves once a
  /// 'done' event is consumed by a subscriber.  If there is no active
  /// subscriber (or it was already cancelled) that Future never resolves.
  /// We intentionally do not await it here.
  @override
  Future<void> close() {
    if (_closed) return Future.value();
    _closed = true;
    unawaited(_controller.close());
    return Future.value();
  }
}
