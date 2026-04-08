import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/succession_position_probe.dart';

void main() {
  test(
    'manual Succession position probe',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runSuccessionPositionProbe([
        '--fen=${env('SUCCESSION_PROBE_FEN', '')}',
        '--moves=${env('SUCCESSION_PROBE_MOVES', '')}',
        '--depth=${env('SUCCESSION_PROBE_DEPTH', '6')}',
        '--time-ms=${env('SUCCESSION_PROBE_TIME_MS', '500')}',
        '--skill=${env('SUCCESSION_PROBE_SKILL', '4')}',
        '--top-count=${env('SUCCESSION_PROBE_TOP_COUNT', '8')}',
        '--candidates=${env('SUCCESSION_PROBE_CANDIDATES', '')}',
      ]);

      final reportFile = File(
        env(
          'SUCCESSION_PROBE_REPORT_PATH',
          '/tmp/succession_position_probe_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Top'));
    },
    skip:
        'Manual Succession position probe; run with --run-skipped when analyzing a specific position.',
  );
}
