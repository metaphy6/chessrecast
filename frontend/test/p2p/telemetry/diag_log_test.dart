// Proof test for roadmap leaf 8.3.b1:
// Local rolling diagnostic log (256 KB ring buffer) persisted, redacted,
// exportable via "Help → Send diagnostics" (opt-in).

import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/services/p2p/telemetry/diag_log.dart';

void main() {
  group('DiagLog — 256 KB ring buffer', () {
    test('log accepts entries and returns them in order', () {
      final log = DiagLog();
      log.append('event_a');
      log.append('event_b');
      log.append('event_c');
      expect(log.entries, equals(['event_a', 'event_b', 'event_c']));
    });

    test('total byte size never exceeds 256 KB', () {
      const maxBytes = 256 * 1024; // 256 KB
      final log = DiagLog();
      // Write more than 256 KB worth of data.
      final chunk = 'x' * 1024; // 1 KB per entry
      for (int i = 0; i < 400; i++) {
        log.append('$i:$chunk');
      }
      final total = log.entries.fold<int>(
        0,
        (sum, e) => sum + e.codeUnits.length,
      );
      expect(
        total,
        lessThanOrEqualTo(maxBytes),
        reason: 'Ring buffer must cap at 256 KB',
      );
    });

    test('oldest entries are evicted when the buffer overflows', () {
      final log = DiagLog();
      // Write enough to push the very first entry out.
      final bigEntry = 'X' * (200 * 1024); // 200 KB
      log.append('first');
      log.append(bigEntry); // fills most of the buffer
      log.append('Y' * (100 * 1024)); // 100 KB — forces rotation past 256 KB
      // "first" must have been evicted.
      expect(log.entries.first, isNot(equals('first')));
    });

    test('export returns non-empty string containing recent entries', () {
      final log = DiagLog();
      log.append('hello_diagnostic');
      final exported = log.export();
      expect(exported, isNotEmpty);
      expect(exported, contains('hello_diagnostic'));
    });

    test('clear empties the log', () {
      final log = DiagLog();
      log.append('some_entry');
      log.clear();
      expect(log.entries, isEmpty);
    });
  });
}
