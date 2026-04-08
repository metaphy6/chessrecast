import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/succession_engine_audit.dart';

void main() {
  test(
    'manual Succession native-engine audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runSuccessionAudit([
        '--baseline-depth=${env('SUCCESSION_AUDIT_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('SUCCESSION_AUDIT_BASELINE_MS', '120')}',
        '--baseline-skill=${env('SUCCESSION_AUDIT_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('SUCCESSION_AUDIT_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('SUCCESSION_AUDIT_REFERENCE_MS', '500')}',
        '--reference-skill=${env('SUCCESSION_AUDIT_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('SUCCESSION_AUDIT_MAX_PLIES', '24')}',
        '--top-count=${env('SUCCESSION_AUDIT_TOP_COUNT', '8')}',
        '--fen=${env('SUCCESSION_AUDIT_FEN', '')}',
        '--moves=${env('SUCCESSION_AUDIT_MOVES', '')}',
      ]);

      final reportFile = File(
        env(
          'SUCCESSION_AUDIT_REPORT_PATH',
          '/tmp/succession_engine_audit_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Worst'));
      expect(report, contains('Final status:'));
    },
    skip:
        'Manual Succession analysis harness; run with --run-skipped when auditing engine quality.',
  );
}
