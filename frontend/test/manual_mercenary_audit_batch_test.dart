import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/mercenary_audit_batch.dart';

void main() {
  test(
    'manual Mercenary batch audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runMercenaryAuditBatch([
        '--baseline-depth=${env('MERC_BATCH_BASELINE_DEPTH', '5')}',
        '--baseline-ms=${env('MERC_BATCH_BASELINE_MS', '250')}',
        '--reference-depth=${env('MERC_BATCH_REFERENCE_DEPTH', '7')}',
        '--reference-ms=${env('MERC_BATCH_REFERENCE_MS', '900')}',
        '--max-plies=${env('MERC_BATCH_MAX_PLIES', '80')}',
        '--top-count=${env('MERC_BATCH_TOP_COUNT', '5')}',
        '--openings=${env('MERC_BATCH_OPENINGS', '')}',
      ]);

      final reportFile = File(
        env('MERC_BATCH_REPORT_PATH', '/tmp/mercenary_audit_batch_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Aggregate:'));
      expect(report, contains('Worst openings:'));
    },
    skip:
        'Manual Mercenary batch audit; run with --run-skipped when comparing opening suites.',
  );
}
