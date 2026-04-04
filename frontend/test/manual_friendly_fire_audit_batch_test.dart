import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/friendly_fire_audit_batch.dart';

void main() {
  test(
    'manual Friendly Fire batch audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runFriendlyFireAuditBatch([
        '--baseline-depth=${env('FRIENDLY_FIRE_BATCH_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('FRIENDLY_FIRE_BATCH_BASELINE_MS', '120')}',
        '--baseline-skill=${env('FRIENDLY_FIRE_BATCH_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('FRIENDLY_FIRE_BATCH_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('FRIENDLY_FIRE_BATCH_REFERENCE_MS', '500')}',
        '--reference-skill=${env('FRIENDLY_FIRE_BATCH_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('FRIENDLY_FIRE_BATCH_MAX_PLIES', '24')}',
        '--top-count=${env('FRIENDLY_FIRE_BATCH_TOP_COUNT', '10')}',
        '--openings=${env('FRIENDLY_FIRE_BATCH_OPENINGS', '')}',
      ]);

      final reportFile = File(
        env(
          'FRIENDLY_FIRE_BATCH_REPORT_PATH',
          '/tmp/friendly_fire_audit_batch_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Aggregate:'));
      expect(report, contains('Worst openings:'));
    },
    skip:
        'Manual Friendly Fire batch audit; run with --run-skipped when comparing opening suites.',
  );
}
