import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/save_the_queen_position_probe.dart';

void main() {
  test(
    'manual Save the Queen position probe',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runSaveTheQueenPositionProbe([
        '--fen=${env('STQ_PROBE_FEN', '')}',
        '--moves=${env('STQ_PROBE_MOVES', '')}',
        '--depth=${env('STQ_PROBE_DEPTH', '6')}',
        '--time-ms=${env('STQ_PROBE_TIME_MS', '500')}',
        '--skill=${env('STQ_PROBE_SKILL', '4')}',
        '--top-count=${env('STQ_PROBE_TOP_COUNT', '8')}',
        '--candidates=${env('STQ_PROBE_CANDIDATES', '')}',
      ]);

      final reportFile = File(
        env(
          'STQ_PROBE_REPORT_PATH',
          '/tmp/save_the_queen_position_probe_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Top'));
    },
    skip:
        'Manual Save the Queen position probe; run with --run-skipped when analyzing a specific position.',
  );
}
