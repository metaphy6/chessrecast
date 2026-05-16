/// §5.5 Transport preset factory.
///
/// Provides named, ready-to-use transport stacks matching the presets
/// documented in [docs/P2P_TEST_PRESETS.md].  Each factory wraps an existing
/// [P2PTransport] (typically a [FakeTransport] pair side) and returns a
/// configured stack implementing [P2PTransport].
///
/// | Preset      | Jitter                   | Loss              | Reorder |
/// |-------------|--------------------------|-------------------|---------|
/// | `clean`     | none                     | 0 %               | none    |
/// | `wifiGood`  | μ = 20 ms, σ = 5 ms      | 0 %               | none    |
/// | `wifiBad`   | μ = 120 ms, σ = 60 ms    | 3 % uniform       | none    |
/// | `mobile4g`  | μ = 80 ms, σ = 40 ms     | 1 % uniform       | none    |
/// | `mobile3g`  | μ = 200 ms, σ = 80 ms    | 5 % uniform       | none    |
/// | `roaming`   | μ = 300 ms, σ = 120 ms   | G-E burst 10/30 % | none    |
library;

import 'dart:math' show Random;
import 'dart:typed_data';

import 'jitter_transport.dart';
import 'lossy_transport.dart';
import 'p2p_transport.dart';

/// Named preset stacks for synthetic-network integration tests.
abstract final class TransportPresets {
  /// **clean** — no jitter, no loss.  Equivalent to a raw [FakeTransport].
  static P2PTransport clean(P2PTransport inner) => _PassThroughTransport(inner);

  /// **wifiGood** — μ = 20 ms, σ = 5 ms, 0 % loss.
  static P2PTransport wifiGood(P2PTransport inner, {Random? rng}) =>
      JitterTransport.wifiGood(inner, rng: rng);

  /// **wifiBad** — μ = 120 ms, σ = 60 ms, 3 % uniform loss.
  static P2PTransport wifiBad(P2PTransport inner, {Random? rng}) =>
      LossyTransport(
        JitterTransport.wifiBad(inner, rng: rng),
        lossRate: 0.03,
        rng: rng,
      );

  /// **mobile4g** — μ = 80 ms, σ = 40 ms, 1 % uniform loss.
  static P2PTransport mobile4g(P2PTransport inner, {Random? rng}) =>
      LossyTransport(
        JitterTransport.mobile4g(inner, rng: rng),
        lossRate: 0.01,
        rng: rng,
      );

  /// **mobile3g** — μ = 200 ms, σ = 80 ms, 5 % uniform loss.
  static P2PTransport mobile3g(P2PTransport inner, {Random? rng}) =>
      LossyTransport(
        JitterTransport.mobile3g(inner, rng: rng),
        lossRate: 0.05,
        rng: rng,
      );

  /// **roaming** — μ = 300 ms, σ = 120 ms, Gilbert–Elliott burst loss
  /// (10 % good-state loss, 30 % bad-state loss, pG→B = 0.05, pB→G = 0.10).
  static P2PTransport roaming(P2PTransport inner, {Random? rng}) =>
      LossyTransport.burst(
        JitterTransport.custom(inner, meanMs: 300, stdDevMs: 120, rng: rng),
        goodLossRate: 0.10,
        badLossRate: 0.30,
        pGoodToBad: 0.05,
        pBadToGood: 0.10,
        rng: rng,
      );
}

/// Minimal pass-through for the "clean" preset.
class _PassThroughTransport implements P2PTransport {
  final P2PTransport _inner;
  _PassThroughTransport(this._inner);

  @override
  Future<void> send(String channel, Uint8List bytes) =>
      _inner.send(channel, bytes);

  @override
  Stream<(String, Uint8List)> get incoming => _inner.incoming;

  @override
  Future<void> close() => _inner.close();
}
