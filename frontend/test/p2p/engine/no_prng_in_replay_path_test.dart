// T-P-007 §9.7 — PRNG output never enters the wire-protocol / state-hash path.
//
// Proof: detectPrngLeak() returns an empty list when move sources are all
// deterministic, and a non-empty list when any PrngOrigin value is present.
// isCleanMove() rejects non-UCI strings and out-of-range evals.
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/services/p2p/replay_purity.dart';

void main() {
  group('T-P-007 §9.7 — No PRNG in replay path', () {
    test('detectPrngLeak returns empty for a deterministic source list', () {
      // Only deterministic objects in the source list.
      final sources = <Object>[
        'e2e4',     // UCI string
        42,         // evalCp
        true,       // some flag
      ];
      expect(detectPrngLeak(sources), isEmpty,
          reason: 'no PRNG values → no leak');
    });

    test('detectPrngLeak identifies a PrngOrigin in the source list', () {
      final prng = const PrngOrigin(0xDEADBEEF);
      final sources = <Object>[
        'e2e4',
        42,
        prng, // ← PRNG leaked in!
      ];
      final leaks = detectPrngLeak(sources);
      expect(leaks.length, equals(1));
      expect(leaks.first, same(prng));
    });

    test('detectPrngLeak finds all leaked PRNG values', () {
      final p1 = const PrngOrigin(1);
      final p2 = const PrngOrigin(2);
      final sources = <Object>['d2d4', p1, 100, p2];
      expect(detectPrngLeak(sources).length, equals(2));
    });

    test('isCleanMove accepts a valid UCI + plausible eval', () {
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'e2e4', evalCp: 30)),
          isTrue);
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'e7e8q', evalCp: 9000)),
          isTrue,
          reason: 'promotion UCI is valid');
    });

    test('isCleanMove rejects UCI strings containing non-board characters', () {
      // Random bytes that happen to be non-[a-h1-8] characters.
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'RAND', evalCp: 0)),
          isFalse);
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'zz99', evalCp: 0)),
          isFalse);
    });

    test('isCleanMove rejects out-of-range evalCp (random bit-pattern)', () {
      // An arbitrary 32-bit random value is very likely outside ±30000.
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'e2e4', evalCp: 99999)),
          isFalse);
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'e2e4', evalCp: -99999)),
          isFalse);
    });

    test('isCleanMove accepts boundary eval values ±30000', () {
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'a1a2', evalCp: 30000)),
          isTrue);
      expect(
          isCleanMove(const ReplayCleanMove(uci: 'a1a2', evalCp: -30000)),
          isTrue);
    });

    test('PrngOrigin is distinct from any deterministic type', () {
      final p = const PrngOrigin(42);
      expect(p, isNot(isA<String>()));
      expect(p, isNot(isA<int>()));
      expect(p, isNot(isA<ReplayCleanMove>()));
    });
  });
}
