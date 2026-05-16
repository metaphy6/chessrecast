/// §5.5 ReorderingTransport — out-of-order delivery wrapper.
///
/// Buffers up to [bufferSize] **clock-channel** frames and randomly swaps
/// adjacent pairs before forwarding.  Non-clock frames (chess, chat, …) are
/// forwarded immediately in FIFO order — only the clock channel is subject
/// to reordering, matching real-world scenarios where the reliable chess
/// data channel preserves order while the low-latency clock channel may
/// deliver frames out of order.
///
/// **No frame is ever dropped.**  Call [flush] to drain the buffer
/// immediately (useful at end of test or game).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'p2p_transport.dart';

/// Reorders clock-channel frames; forwards all other channels immediately.
class ReorderingTransport implements P2PTransport {
  static const _clockChannel = 'clock';

  final P2PTransport _inner;
  final int _bufferSize;
  final double _swapProbability;
  final math.Random _rng;

  // Buffer for outgoing clock frames.
  final List<(String, Uint8List)> _outBuffer = [];
  // Buffer for incoming clock frames.
  final List<(String, Uint8List)> _inBuffer = [];

  late final StreamController<(String, Uint8List)> _inController;
  late final StreamSubscription<(String, Uint8List)> _innerSub;

  bool _closed = false;

  ReorderingTransport(
    this._inner, {
    required double swapProbability,
    required int bufferSize,
    math.Random? rng,
  }) : _swapProbability = swapProbability,
       _bufferSize = bufferSize,
       _rng = rng ?? math.Random() {
    _inController = StreamController(sync: true);
    _innerSub = _inner.incoming.listen(_onIncoming);
  }

  // ---------------------------------------------------------------------------
  // Reorder helpers
  // ---------------------------------------------------------------------------

  /// Randomly swap adjacent pairs in [buf] according to [_swapProbability].
  void _maybeShuffle(List<(String, Uint8List)> buf) {
    for (var i = 0; i < buf.length - 1; i++) {
      if (_rng.nextDouble() < _swapProbability) {
        final tmp = buf[i];
        buf[i] = buf[i + 1];
        buf[i + 1] = tmp;
      }
    }
  }

  void _flushBuffer(
    List<(String, Uint8List)> buf,
    void Function((String, Uint8List)) emit,
  ) {
    _maybeShuffle(buf);
    for (final msg in buf) {
      emit(msg);
    }
    buf.clear();
  }

  // ---------------------------------------------------------------------------
  // Incoming path
  // ---------------------------------------------------------------------------

  void _onIncoming((String, Uint8List) msg) {
    if (_closed || _inController.isClosed) return;
    if (msg.$1 != _clockChannel) {
      _inController.add(msg);
      return;
    }
    _inBuffer.add(msg);
    if (_inBuffer.length >= _bufferSize) {
      _flushBuffer(_inBuffer, _inController.add);
    }
  }

  // ---------------------------------------------------------------------------
  // P2PTransport implementation
  // ---------------------------------------------------------------------------

  @override
  Future<void> send(String channel, Uint8List bytes) {
    if (_closed) throw StateError('ReorderingTransport is closed');
    if (channel != _clockChannel) {
      return _inner.send(channel, bytes);
    }
    _outBuffer.add((channel, bytes));
    if (_outBuffer.length >= _bufferSize) {
      return _flushOut();
    }
    return Future.value();
  }

  Future<void> _flushOut() {
    _maybeShuffle(_outBuffer);
    final toSend = List.of(_outBuffer);
    _outBuffer.clear();
    // Fire-and-forget: for FakeTransport (sync) this delivers synchronously.
    // For production transports the caller should await send() for backpressure.
    for (final msg in toSend) {
      unawaited(_inner.send(msg.$1, msg.$2));
    }
    return Future.value();
  }

  /// Drain any buffered frames immediately (outgoing and incoming).
  Future<void> flush() async {
    if (_closed) return;
    // Flush outgoing
    if (_outBuffer.isNotEmpty) {
      await _flushOut();
    }
    // Flush incoming
    if (_inBuffer.isNotEmpty) {
      _flushBuffer(_inBuffer, (msg) {
        if (!_closed && !_inController.isClosed) _inController.add(msg);
      });
    }
  }

  @override
  Stream<(String, Uint8List)> get incoming => _inController.stream;

  @override
  Future<void> close() {
    if (_closed) return Future.value();
    _closed = true;
    _outBuffer.clear();
    _inBuffer.clear();
    _innerSub.cancel();
    unawaited(_inController.close());
    return _inner.close();
  }
}
