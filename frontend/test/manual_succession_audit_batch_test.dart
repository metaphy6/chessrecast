import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/succession_audit_batch.dart';

void main() {
  test(
    'manual Succession batch audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runSuccessionAuditBatch([
        '--baseline-depth=${env('SUCCESSION_BATCH_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('SUCCESSION_BATCH_BASELINE_MS', '120')}',
        '--baseline-skill=${env('SUCCESSION_BATCH_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('SUCCESSION_BATCH_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('SUCCESSION_BATCH_REFERENCE_MS', '500')}',
        '--reference-skill=${env('SUCCESSION_BATCH_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('SUCCESSION_BATCH_MAX_PLIES', '24')}',
        '--top-count=${env('SUCCESSION_BATCH_TOP_COUNT', '10')}',
        '--isolate-openings=${env('SUCCESSION_BATCH_ISOLATE_OPENINGS', 'true')}',
        '--openings=${env('SUCCESSION_BATCH_OPENINGS', '')}',
      ]);

      final reportFile = File(
        env(
          'SUCCESSION_BATCH_REPORT_PATH',
          '/tmp/succession_audit_batch_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Aggregate:'));
      expect(report, contains('Worst openings:'));
    },
    skip:
        'Manual Succession batch audit; run with --run-skipped when comparing opening suites.',
  );
}
