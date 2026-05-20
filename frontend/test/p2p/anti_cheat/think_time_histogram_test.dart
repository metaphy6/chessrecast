// §13.2.b2 — move-time histogram test.
//
// The histogram is computed from LOCAL clock observations only — each peer
// measures how long it waited for the opponent's move using its own wall clock.
// The opponent cannot forge or suppress the histogram shown to the other side.
library;

import 'package:chessrecast/services/p2p/anti_cheat/think_time_histogram.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ThinkTimeHistogram hist;

  setUp(() => hist = ThinkTimeHistogram());

  group('§13.2.b2 — ThinkTimeHistogram basic recording', () {
    test('starts empty', () {
      expect(hist.count, 0);
      expect(hist.moveTimes, isEmpty);
    });

    test('records a single move time', () {
      hist.record(1000);
      expect(hist.count, 1);
      expect(hist.moveTimes, [1000]);
    });

    test('records multiple move times', () {
      hist
        ..record(500)
        ..record(1500)
        ..record(1000);
      expect(hist.count, 3);
      expect(hist.moveTimes, [500, 1500, 1000]);
    });

    test('clear resets the histogram', () {
      hist.record(1000);
      hist.clear();
      expect(hist.count, 0);
      expect(hist.moveTimes, isEmpty);
    });
  });

  group('§13.2.b2 — ThinkTimeHistogram statistics', () {
    test('minMs and maxMs for single entry', () {
      hist.record(800);
      expect(hist.minMs, 800);
      expect(hist.maxMs, 800);
    });

    test('minMs and maxMs for multiple entries', () {
      hist
        ..record(200)
        ..record(800)
        ..record(500);
      expect(hist.minMs, 200);
      expect(hist.maxMs, 800);
    });

    test('meanMs is average', () {
      hist
        ..record(200)
        ..record(400)
        ..record(600);
      expect(hist.meanMs, closeTo(400.0, 0.01));
    });

    test('stdDevMs is 0 for single entry', () {
      hist.record(1000);
      expect(hist.stdDevMs, closeTo(0.0, 0.01));
    });

    test('stdDevMs is computed for multiple entries', () {
      // Mean = 4, variance = ((1-4)^2 + (4-4)^2 + (7-4)^2) / 3 = 6.
      // stdDev = sqrt(6) ≈ 2.449.
      hist
        ..record(1)
        ..record(4)
        ..record(7);
      expect(hist.stdDevMs, closeTo(2.449, 0.01));
    });
  });

  group('§13.2.b2 — ThinkTimeHistogram integrity', () {
    test('moveTimes is an unmodifiable view', () {
      hist.record(1000);
      // Attempting to modify the returned list should throw.
      expect(() => hist.moveTimes.add(999), throwsA(isA<UnsupportedError>()));
    });
  });

  group(
    '§13.4.b1 — Performance: histogram record is O(1) / trivially fast',
    () {
      test('recording 10 000 moves completes quickly', () {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 10000; i++) {
          hist.record(i);
        }
        sw.stop();
        // Even on a slow CI machine, 10k list appends should be < 100 ms.
        expect(sw.elapsedMilliseconds, lessThan(100));
      });
    },
  );

  group('§13.4.b4 — Integrity: histogram uses local data only', () {
    test('record accepts only int (local-clock measurement type)', () {
      // The API type `int` prevents accidental passing of a
      // double/Duration from an opponent-reported timestamp.
      hist.record(1234);
      expect(hist.moveTimes.first, isA<int>());
    });
  });
}
