import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/truce_position_probe.dart';

void main() {
  test(
    'manual Truce position probe',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runTrucePositionProbe([
        '--fen=${env('TRUCE_PROBE_FEN', '')}',
        '--moves=${env('TRUCE_PROBE_MOVES', '')}',
        '--depth=${env('TRUCE_PROBE_DEPTH', '6')}',
        '--time-ms=${env('TRUCE_PROBE_TIME_MS', '1200')}',
        '--top-count=${env('TRUCE_PROBE_TOP_COUNT', '8')}',
        '--candidates=${env('TRUCE_PROBE_CANDIDATES', '')}',
      ]);

      final reportFile = File(
        env('TRUCE_PROBE_REPORT_PATH', '/tmp/truce_position_probe_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Top'));
    },
    skip:
        'Manual Truce position probe; run with --run-skipped when analyzing a specific FEN.',
  );
}
