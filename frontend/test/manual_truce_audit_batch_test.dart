import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/truce_audit_batch.dart';

void main() {
  test(
    'manual Truce batch audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final stopAtDeltaRaw = Platform.environment['TRUCE_BATCH_STOP_AT_DELTA'];

      final args = [
        '--baseline-depth=${env('TRUCE_BATCH_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('TRUCE_BATCH_BASELINE_MS', '120')}',
        '--baseline-skill=${env('TRUCE_BATCH_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('TRUCE_BATCH_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('TRUCE_BATCH_REFERENCE_MS', '500')}',
        '--reference-skill=${env('TRUCE_BATCH_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('TRUCE_BATCH_MAX_PLIES', '24')}',
        '--top-count=${env('TRUCE_BATCH_TOP_COUNT', '10')}',
        '--suite=${env('TRUCE_BATCH_SUITE', 'default')}',
        '--openings=${env('TRUCE_BATCH_OPENINGS', '')}',
      ];
      if (stopAtDeltaRaw != null && stopAtDeltaRaw.trim().isNotEmpty) {
        args.add('--stop-at-delta=${stopAtDeltaRaw.trim()}');
      }

      final report = runTruceAuditBatch(args);

      final reportFile = File(
        env('TRUCE_BATCH_REPORT_PATH', '/tmp/truce_audit_batch_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Aggregate:'));
      expect(report, contains('Worst openings:'));
    },
    skip:
        'Manual Truce batch audit; run with --run-skipped when comparing opening suites.',
  );
}
