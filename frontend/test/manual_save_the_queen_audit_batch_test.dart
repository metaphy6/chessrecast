import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/save_the_queen_audit_batch.dart';

void main() {
  test(
    'manual Save the Queen batch audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final stopAtDeltaRaw = Platform.environment['STQ_BATCH_STOP_AT_DELTA'];

      final args = [
        '--baseline-depth=${env('STQ_BATCH_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('STQ_BATCH_BASELINE_MS', '120')}',
        '--baseline-skill=${env('STQ_BATCH_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('STQ_BATCH_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('STQ_BATCH_REFERENCE_MS', '500')}',
        '--reference-skill=${env('STQ_BATCH_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('STQ_BATCH_MAX_PLIES', '24')}',
        '--top-count=${env('STQ_BATCH_TOP_COUNT', '10')}',
        '--isolate-openings=${env('STQ_BATCH_ISOLATE_OPENINGS', 'true')}',
        '--openings=${env('STQ_BATCH_OPENINGS', '')}',
      ];
      if (stopAtDeltaRaw != null && stopAtDeltaRaw.trim().isNotEmpty) {
        args.add('--stop-at-delta=${stopAtDeltaRaw.trim()}');
      }

      final report = runSaveTheQueenAuditBatch(args);

      final reportFile = File(
        env(
          'STQ_BATCH_REPORT_PATH',
          '/tmp/save_the_queen_audit_batch_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Aggregate:'));
      expect(report, contains('Worst openings:'));
    },
    skip:
        'Manual Save the Queen batch audit; run with --run-skipped when comparing opening suites.',
  );
}
