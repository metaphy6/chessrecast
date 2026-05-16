/// §5.5 LossyTransport — packet-loss transport wrapper.
///
/// Two modes:
///
/// 1. **Uniform**: a fixed [lossRate] (0.0 – 1.0) applied to all channels
///    or per-channel via [channelLossRates].
///
/// 2. **Gilbert–Elliott burst** ([LossyTransport.burst]): a two-state Markov
///    chain with separate loss rates for the Good and Bad states, and
///    transition probabilities [pGoodToBad] / [pBadToGood].
///
/// Loss is applied symmetrically to both [send] (outgoing) and [incoming]
/// (incoming).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'p2p_transport.dart';

/// Configurable packet-loss wrapper for testing under adverse conditions.
class LossyTransport implements P2PTransport {
  final P2PTransport _inner;
  final math.Random _rng;

  // Uniform-mode loss rates: keyed by channel name; '*' is the catch-all.
  final Map<String, double> _channelRates;

  // Gilbert–Elliott state.
  bool _inBadState;
  final double? _goodLossRate;
  final double? _badLossRate;
  final double? _pGoodToBad;
  final double? _pBadToGood;

  late final StreamController<(String, Uint8List)> _inController;
  late final StreamSubscription<(String, Uint8List)> _innerSub;

  bool _closed = false;

  // ---------------------------------------------------------------------------
  // Private constructor
  // ---------------------------------------------------------------------------
  LossyTransport._({
    required P2PTransport inner,
    required Map<String, double> channelRates,
    required math.Random rng,
    double? goodLossRate,
    double? badLossRate,
    double? pGoodToBad,
    double? pBadToGood,
    bool startInBadState = false,
  }) : _inner = inner,
       _channelRates = channelRates,
       _rng = rng,
       _goodLossRate = goodLossRate,
       _badLossRate = badLossRate,
       _pGoodToBad = pGoodToBad,
       _pBadToGood = pBadToGood,
       _inBadState = startInBadState {
    _inController = StreamController(sync: true);
    _innerSub = _inner.incoming.listen(_onIncoming);
  }

  // ---------------------------------------------------------------------------
  // Factory constructors
  // ---------------------------------------------------------------------------

  /// Uniform loss with an optional per-channel override map.
  ///
  /// [lossRate] is the default rate for all channels not listed in
  /// [channelLossRates].  Values must be in [0.0, 1.0].
  factory LossyTransport(
    P2PTransport inner, {
    double lossRate = 0.0,
    Map<String, double>? channelLossRates,
    math.Random? rng,
  }) {
    final rates = <String, double>{'*': lossRate};
    if (channelLossRates != null) rates.addAll(channelLossRates);
    return LossyTransport._(
      inner: inner,
      channelRates: rates,
      rng: rng ?? math.Random(),
    );
  }

  /// Gilbert–Elliott two-state Markov burst-loss model.
  ///
  /// [goodLossRate]  — per-frame loss probability in the Good state.
  /// [badLossRate]   — per-frame loss probability in the Bad state.
  /// [pGoodToBad]    — probability of transitioning Good → Bad per frame.
  /// [pBadToGood]    — probability of transitioning Bad → Good per frame.
  /// [startInBadState] — if true, chain starts in Bad state (default: Good).
  factory LossyTransport.burst(
    P2PTransport inner, {
    required double goodLossRate,
    required double badLossRate,
    required double pGoodToBad,
    required double pBadToGood,
    bool startInBadState = false,
    math.Random? rng,
  }) {
    return LossyTransport._(
      inner: inner,
      channelRates: const {},
      rng: rng ?? math.Random(),
      goodLossRate: goodLossRate,
      badLossRate: badLossRate,
      pGoodToBad: pGoodToBad,
      pBadToGood: pBadToGood,
      startInBadState: startInBadState,
    );
  }

  // ---------------------------------------------------------------------------
  // Loss decision helpers
  // ---------------------------------------------------------------------------

  bool _shouldDrop(String channel) {
    if (_goodLossRate != null) {
      // Gilbert–Elliott mode.
      final lossRate = _inBadState ? _badLossRate! : _goodLossRate!;
      final drop = _rng.nextDouble() < lossRate;
      // Advance Markov state.
      if (_inBadState) {
        if (_rng.nextDouble() < _pBadToGood!) _inBadState = false;
      } else {
        if (_rng.nextDouble() < _pGoodToBad!) _inBadState = true;
      }
      return drop;
    }
    // Uniform mode.
    final rate = _channelRates[channel] ?? _channelRates['*'] ?? 0.0;
    return _rng.nextDouble() < rate;
  }

  // ---------------------------------------------------------------------------
  // P2PTransport implementation
  // ---------------------------------------------------------------------------

  void _onIncoming((String, Uint8List) msg) {
    if (_closed || _inController.isClosed) return;
    if (!_shouldDrop(msg.$1)) {
      _inController.add(msg);
    }
  }

  @override
  Future<void> send(String channel, Uint8List bytes) {
    if (_closed) throw StateError('LossyTransport is closed');
    if (_shouldDrop(channel)) return Future.value();
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
