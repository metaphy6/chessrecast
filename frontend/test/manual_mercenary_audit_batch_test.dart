import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/mercenary_audit_batch.dart';

void main() {
  test(
    'manual Mercenary batch audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final stopAtDeltaRaw = Platform.environment['MERC_BATCH_STOP_AT_DELTA'];

      final args = [
        '--baseline-depth=${env('MERC_BATCH_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('MERC_BATCH_BASELINE_MS', '120')}',
        '--baseline-skill=${env('MERC_BATCH_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('MERC_BATCH_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('MERC_BATCH_REFERENCE_MS', '500')}',
        '--reference-skill=${env('MERC_BATCH_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('MERC_BATCH_MAX_PLIES', '24')}',
        '--top-count=${env('MERC_BATCH_TOP_COUNT', '10')}',
        '--openings=${env('MERC_BATCH_OPENINGS', '')}',
      ];
      if (stopAtDeltaRaw != null && stopAtDeltaRaw.trim().isNotEmpty) {
        args.add('--stop-at-delta=${stopAtDeltaRaw.trim()}');
      }

      final report = runMercenaryAuditBatch(args);

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
