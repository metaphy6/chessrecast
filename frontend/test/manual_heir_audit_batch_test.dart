import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/heir_audit_batch.dart';

void main() {
  test(
    'manual Heir batch audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final stopAtDeltaRaw = Platform.environment['HEIR_BATCH_STOP_AT_DELTA'];
      final liveProgress = env('HEIR_BATCH_LIVE_PROGRESS', '1') != '0';

      final args = [
        '--baseline-depth=${env('HEIR_BATCH_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('HEIR_BATCH_BASELINE_MS', '120')}',
        '--baseline-skill=${env('HEIR_BATCH_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('HEIR_BATCH_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('HEIR_BATCH_REFERENCE_MS', '500')}',
        '--reference-skill=${env('HEIR_BATCH_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('HEIR_BATCH_MAX_PLIES', '24')}',
        '--top-count=${env('HEIR_BATCH_TOP_COUNT', '10')}',
        '--openings=${env('HEIR_BATCH_OPENINGS', '')}',
      ];
      if (stopAtDeltaRaw != null && stopAtDeltaRaw.trim().isNotEmpty) {
        args.add('--stop-at-delta=${stopAtDeltaRaw.trim()}');
      }

      final report = runHeirAuditBatch(
        args,
        onProgress: liveProgress ? (message) => print(message) : null,
      );

      final reportFile = File(
        env('HEIR_BATCH_REPORT_PATH', '/tmp/heir_audit_batch_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Aggregate:'));
      expect(report, contains('Worst openings:'));
    },
    skip:
        'Manual Heir batch audit; run with --run-skipped when comparing opening suites.',
  );
}
