/// §5.5 JitterTransport — variable-latency transport wrapper.
///
/// Wraps an inner [P2PTransport] and adds independent per-frame Gaussian
/// delay to outgoing frames.  The delay model uses Box–Muller sampling with
/// a floor of 0 ms (no negative delays).  Incoming frames are similarly
/// delayed before being exposed on [incoming].
///
/// Named factory constructors provide realistic presets:
/// - [wifiGood]   μ = 20 ms,  σ =  5 ms
/// - [wifiBad]    μ = 120 ms, σ = 60 ms
/// - [mobile4g]   μ =  80 ms, σ = 40 ms
/// - [mobile3g]   μ = 200 ms, σ = 80 ms
///
/// **No frame is ever dropped.**  Jitter only delays; use [LossyTransport]
/// for packet loss.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'p2p_transport.dart';

/// Variable-latency wrapper that adds independent Gaussian delay per frame.
class JitterTransport implements P2PTransport {
  final P2PTransport _inner;
  final double _meanMs;
  final double _stdDevMs;
  final math.Random _rng;

  late final StreamController<(String, Uint8List)> _inController;
  late final StreamSubscription<(String, Uint8List)> _innerSub;

  bool _closed = false;

  JitterTransport._(
    this._inner, {
    required double meanMs,
    required double stdDevMs,
    math.Random? rng,
  }) : _meanMs = meanMs,
       _stdDevMs = stdDevMs,
       _rng = rng ?? math.Random() {
    _inController = StreamController(sync: true);
    _innerSub = _inner.incoming.listen(_scheduleDelayed);
  }

  /// Wi-Fi (good conditions): μ = 20 ms, σ = 5 ms.
  factory JitterTransport.wifiGood(P2PTransport inner, {math.Random? rng}) =>
      JitterTransport._(inner, meanMs: 20, stdDevMs: 5, rng: rng);

  /// Wi-Fi (bad conditions / congested): μ = 120 ms, σ = 60 ms.
  factory JitterTransport.wifiBad(P2PTransport inner, {math.Random? rng}) =>
      JitterTransport._(inner, meanMs: 120, stdDevMs: 60, rng: rng);

  /// Mobile 4G: μ = 80 ms, σ = 40 ms.
  factory JitterTransport.mobile4g(P2PTransport inner, {math.Random? rng}) =>
      JitterTransport._(inner, meanMs: 80, stdDevMs: 40, rng: rng);

  /// Mobile 3G: μ = 200 ms, σ = 80 ms.
  factory JitterTransport.mobile3g(P2PTransport inner, {math.Random? rng}) =>
      JitterTransport._(inner, meanMs: 200, stdDevMs: 80, rng: rng);

  /// Custom parameters for preset builders and other specialised use cases.
  factory JitterTransport.custom(
    P2PTransport inner, {
    required double meanMs,
    required double stdDevMs,
    math.Random? rng,
  }) => JitterTransport._(inner, meanMs: meanMs, stdDevMs: stdDevMs, rng: rng);

  // Box–Muller transform: produces one standard-normal sample.
  double _gaussian() {
    final u1 = _rng.nextDouble();
    final u2 = _rng.nextDouble();
    // Guard against log(0).
    final safe1 = u1 == 0.0 ? double.minPositive : u1;
    return math.sqrt(-2.0 * math.log(safe1)) * math.cos(2.0 * math.pi * u2);
  }

  Duration _sampleDelay() {
    final ms = (_meanMs + _stdDevMs * _gaussian()).clamp(0.0, double.infinity);
    return Duration(microseconds: (ms * 1000).round());
  }

  void _scheduleDelayed((String, Uint8List) msg) {
    final delay = _sampleDelay();
    // Each frame gets its own independent timer — no serialisation.
    Future.delayed(delay, () {
      if (!_closed && !_inController.isClosed) {
        _inController.add(msg);
      }
    });
  }

  @override
  Future<void> send(String channel, Uint8List bytes) {
    if (_closed) throw StateError('JitterTransport is closed');
    return _inner.send(channel, bytes);
  }

  @override
  Stream<(String, Uint8List)> get incoming => _inController.stream;

  @override
  Future<void> close() {
    if (_closed) return Future.value();
    _closed = true;
    _innerSub.cancel();
    unawaited(_inController.close());
    return _inner.close();
  }
}
