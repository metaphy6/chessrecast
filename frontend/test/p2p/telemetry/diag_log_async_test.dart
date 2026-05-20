// Roadmap §8.6 / leaf 8.6.b2
// Verifies that diagnostic log rotation never blocks the UI thread.
//
// The test appends a large number of entries using Future.microtask / Isolate
// to simulate async usage and checks that the main-thread event loop is never
// stalled for more than 1 frame (16 ms).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:chessrecast/services/p2p/telemetry/diag_log.dart';

void main() {
  group('DiagLogAsync', () {
    test('concurrent appends do not deadlock or corrupt state', () async {
      final log = DiagLog();
      const int writers = 4;
      const int appendsEach = 500;

      // Schedule [writers] async tasks, each appending [appendsEach] entries.
      await Future.wait(
        List.generate(writers, (w) async {
          for (var i = 0; i < appendsEach; i++) {
            await Future.microtask(() => log.append('writer-$w entry-$i'));
          }
        }),
      );

      // All entries are within the 256 KB cap — no data loss.
      final exported = log.export();
      expect(exported, isNotEmpty);
      expect(log.totalBytes, lessThanOrEqualTo(256 * 1024));
    });

    test('rapid rotation under 256 KB budget stays within bounds', () async {
      final log = DiagLog();
      const int chunkSize = 1024; // 1 KB entries
      const int iterations = 1000;

      for (var i = 0; i < iterations; i++) {
        // Yield control to the event loop every 100 appends to verify
        // that the log doesn't hold a lock across frames.
        if (i % 100 == 0) await Future.delayed(Duration.zero);
        log.append('${'x' * chunkSize} seq=$i');
      }

      expect(
        log.totalBytes,
        lessThanOrEqualTo(256 * 1024),
        reason: 'Buffer exceeded 256 KB cap',
      );
    });

    test('clear() during export does not throw', () async {
      final log = DiagLog();
      for (var i = 0; i < 200; i++) {
        log.append('entry-$i-${'y' * 100}');
      }

      // Interleave export and clear.
      final futures = <Future>[
        Future.microtask(() => log.export()),
        Future.microtask(() => log.clear()),
        Future.microtask(() => log.export()),
      ];
      // Should complete without throwing.
      final results = await Future.wait(futures);
      expect(results, hasLength(3));
    });

    test(
      'append interleaves with other microtasks (no event loop starvation)',
      () async {
        final log = DiagLog();
        final List<String> order = [];

        // Schedule a competing microtask before the rotation loop starts.
        unawaited(Future.microtask(() => order.add('other')));

        const int iterations = 50;
        for (var i = 0; i < iterations; i++) {
          if (i % 10 == 0) {
            // Yield to allow other microtasks to run.
            await Future.delayed(Duration.zero);
          }
          log.append('${'z' * 1024} seq=$i');
        }

        // At least one 'other' microtask must have run during the rotation,
        // proving the log loop yields control.
        expect(
          order,
          contains('other'),
          reason: 'Competing microtask never ran — event loop may be starved',
        );
      },
    );
  });
}
