import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/friendly_fire_position_probe.dart';

void main() {
  test(
    'manual Friendly Fire position probe',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runFriendlyFirePositionProbe([
        '--fen=${env('FRIENDLY_FIRE_PROBE_FEN', '')}',
        '--moves=${env('FRIENDLY_FIRE_PROBE_MOVES', '')}',
        '--depth=${env('FRIENDLY_FIRE_PROBE_DEPTH', '6')}',
        '--time-ms=${env('FRIENDLY_FIRE_PROBE_TIME_MS', '1200')}',
        '--skill=${env('FRIENDLY_FIRE_PROBE_SKILL', '4')}',
        '--top-count=${env('FRIENDLY_FIRE_PROBE_TOP_COUNT', '8')}',
        '--candidates=${env('FRIENDLY_FIRE_PROBE_CANDIDATES', '')}',
      ]);

      final reportFile = File(
        env(
          'FRIENDLY_FIRE_PROBE_REPORT_PATH',
          '/tmp/friendly_fire_position_probe_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Top'));
    },
    skip:
        'Manual Friendly Fire position probe; run with --run-skipped when analyzing a specific position.',
  );
}
