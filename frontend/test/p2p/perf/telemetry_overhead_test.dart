// Roadmap §8.6 / leaf 8.6.b1
// Verifies that the telemetry path adds ≤ 50 µs per move.
//
// The test measures the wall-clock cost of appending a typical diagnostic
// log entry (after PII redaction) against the 50 µs budget. The budget is
// intentionally generous to remain stable on CI runners.

import 'package:flutter_test/flutter_test.dart';

import 'package:chessrecast/services/p2p/telemetry/diag_log.dart';
import 'package:chessrecast/services/p2p/telemetry/diag_redactor.dart';

void main() {
  group('TelemetryOverhead', () {
    test('single append + redact completes in ≤ 50 µs on average', () {
      const int iterations = 1000;
      const int budgetMicros = 50;

      final log = DiagLog();
      final redactor = DiagRedactor();

      // Warm up (JIT / AOT priming).
      for (var i = 0; i < 20; i++) {
        final entry = redactor.redact('move e2e4 ts=${DateTime.now().millisecondsSinceEpoch} peer=192.168.1.1');
        log.append(entry);
      }
      log.clear();

      // Benchmark.
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        final entry = redactor.redact(
          'move e2e4 seq=$i ts=${DateTime.now().millisecondsSinceEpoch} '
          'peer=192.168.1.42 key=abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        );
        log.append(entry);
      }
      sw.stop();

      final avgMicros = sw.elapsedMicroseconds / iterations;
      // ignore: avoid_print
      print('TelemetryOverhead: avg=${avgMicros.toStringAsFixed(2)} µs/append+redact');

      expect(
        avgMicros,
        lessThanOrEqualTo(budgetMicros.toDouble()),
        reason: 'telemetry path exceeds $budgetMicros µs budget; avg=$avgMicros µs',
      );
    });

    test('DiagLog.export() on 256 KB buffer completes in ≤ 5 ms', () {
      const int budgetMs = 5;
      final log = DiagLog();

      // Fill to near-capacity.
      final chunk = 'x' * 512;
      while (true) {
        final before = log.totalBytes;
        log.append(chunk);
        if (log.totalBytes <= before) break; // eviction started → buffer full
      }

      final sw = Stopwatch()..start();
      final _ = log.export();
      sw.stop();

      // ignore: avoid_print
      print('DiagLog.export() elapsed=${sw.elapsedMilliseconds} ms');
      expect(
        sw.elapsedMilliseconds,
        lessThanOrEqualTo(budgetMs),
        reason: 'DiagLog.export() took ${sw.elapsedMilliseconds} ms (budget $budgetMs ms)',
      );
    });
  });
}
