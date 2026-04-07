import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/save_the_queen_engine_audit.dart';

void main() {
  test(
    'manual Save the Queen native-engine audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runSaveTheQueenAudit([
        '--baseline-depth=${env('STQ_AUDIT_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('STQ_AUDIT_BASELINE_MS', '120')}',
        '--baseline-skill=${env('STQ_AUDIT_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('STQ_AUDIT_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('STQ_AUDIT_REFERENCE_MS', '500')}',
        '--reference-skill=${env('STQ_AUDIT_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('STQ_AUDIT_MAX_PLIES', '24')}',
        '--top-count=${env('STQ_AUDIT_TOP_COUNT', '8')}',
        '--fen=${env('STQ_AUDIT_FEN', '')}',
        '--moves=${env('STQ_AUDIT_MOVES', '')}',
      ]);

      final reportFile = File(
        env(
          'STQ_AUDIT_REPORT_PATH',
          '/tmp/save_the_queen_engine_audit_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Worst'));
      expect(report, contains('Final status:'));
    },
    skip:
        'Manual Save the Queen analysis harness; run with --run-skipped when auditing engine quality.',
  );
}
