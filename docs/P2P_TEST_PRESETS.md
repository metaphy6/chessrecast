# P2P Test Presets

<!-- §5.5 proof document — referenced by transport_stack_composition_test.dart -->

This document lists the named synthetic-network presets available via
`TransportPresets` (`frontend/lib/services/p2p/transport/fake/transport_presets.dart`).
Each preset wraps a `P2PTransport` (typically one side of a `FakeTransport.pair()`)
and simulates a specific network condition.

## Preset table

| Preset     | Class / Factory                              | Jitter μ / σ      | Loss model                       | Reorder |
|------------|----------------------------------------------|-------------------|----------------------------------|---------|
| `clean`    | `TransportPresets.clean(inner)`              | none              | 0 %                              | none    |
| `wifiGood` | `TransportPresets.wifiGood(inner)`           | 20 ms / 5 ms      | 0 %                              | none    |
| `wifiBad`  | `TransportPresets.wifiBad(inner)`            | 120 ms / 60 ms    | 3 % uniform                      | none    |
| `mobile4g` | `TransportPresets.mobile4g(inner)`           | 80 ms / 40 ms     | 1 % uniform                      | none    |
| `mobile3g` | `TransportPresets.mobile3g(inner)`           | 200 ms / 80 ms    | 5 % uniform                      | none    |
| `roaming`  | `TransportPresets.roaming(inner)`            | 300 ms / 120 ms   | G-E burst: 10 % good / 30 % bad  | none    |

## Gilbert–Elliott burst model (used by `roaming`)

The `roaming` preset applies a two-state Markov chain:

| Parameter     | Value  | Meaning                                      |
|---------------|--------|----------------------------------------------|
| pGood→Bad     | 0.05   | 5 % chance of entering congestion per frame  |
| pBad→Good     | 0.10   | 10 % chance of recovering per frame          |
| goodLossRate  | 0.10   | 10 % loss while in the Good state            |
| badLossRate   | 0.30   | 30 % loss while in the Bad state             |

This models mobile data handed off between towers (brief congestion bursts of
~10 frames average duration).

## Usage example

```dart
// In a synthetic-network integration test (§5.5 / L5):
final (innerA, innerB) = FakeTransport.pair();
final transport = TransportPresets.mobile4g(innerA);

// innerB receives frames after jitter + 1 % loss
innerB.incoming.listen((t) { /* ... */ });

transport.send('chess', myFrame);
await Future.delayed(const Duration(milliseconds: 500)); // budget ≥ 3×μ
```

## Composition

Presets compose: wrap the output of one preset as the `inner` of another.

```dart
// Extra jitter on top of wifiBad:
final (innerA, _) = FakeTransport.pair();
final extra = JitterTransport.custom(
  TransportPresets.wifiBad(innerA),
  meanMs: 50, stdDevMs: 20,
);
```

## Raw transport building blocks

When no preset matches your scenario, compose manually:

| Class                | Purpose                                        |
|----------------------|------------------------------------------------|
| `FakeTransport`      | Baseline zero-loss FIFO in-memory pipe         |
| `JitterTransport`    | Per-frame Gaussian latency (Box–Muller)        |
| `LossyTransport`     | Uniform or Gilbert–Elliott burst packet loss   |
| `ReorderingTransport`| Random adjacent-swap reordering (clock only)  |

All live under `frontend/lib/services/p2p/transport/fake/`.

## Determinism

Pass an explicit `rng: Random(seed)` to any factory to get reproducible test runs.
See `frontend/test/p2p/transport/transport_determinism_test.dart` for examples.
