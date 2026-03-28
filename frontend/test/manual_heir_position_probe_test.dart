import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/heir_position_probe.dart';

void main() {
  test(
    'manual Heir position probe',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runHeirPositionProbe([
        '--fen=${env('HEIR_PROBE_FEN', '')}',
        '--depth=${env('HEIR_PROBE_DEPTH', '6')}',
        '--time-ms=${env('HEIR_PROBE_TIME_MS', '1200')}',
        '--top-count=${env('HEIR_PROBE_TOP_COUNT', '8')}',
        '--candidates=${env('HEIR_PROBE_CANDIDATES', '')}',
      ]);

      final reportFile = File(
        env('HEIR_PROBE_REPORT_PATH', '/tmp/heir_position_probe_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Top'));
    },
    skip:
        'Manual Heir position probe; run with --run-skipped when analyzing a specific FEN.',
  );
}
