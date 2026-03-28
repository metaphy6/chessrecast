import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/mercenary_position_probe.dart';

void main() {
  test(
    'manual Mercenary position probe',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runMercenaryPositionProbe([
        '--fen=${env('MERC_PROBE_FEN', '')}',
        '--depth=${env('MERC_PROBE_DEPTH', '6')}',
        '--time-ms=${env('MERC_PROBE_TIME_MS', '1200')}',
        '--top-count=${env('MERC_PROBE_TOP_COUNT', '8')}',
        '--candidates=${env('MERC_PROBE_CANDIDATES', '')}',
      ]);

      final reportFile = File(
        env(
          'MERC_PROBE_REPORT_PATH',
          '/tmp/mercenary_position_probe_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Top'));
    },
    skip:
        'Manual Mercenary position probe; run with --run-skipped when analyzing a specific FEN.',
  );
}
