import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/heir_engine_audit.dart';

void main() {
  test(
    'manual Heir native-engine audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runHeirAudit([
        '--baseline-depth=${env('HEIR_AUDIT_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('HEIR_AUDIT_BASELINE_MS', '120')}',
        '--baseline-skill=${env('HEIR_AUDIT_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('HEIR_AUDIT_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('HEIR_AUDIT_REFERENCE_MS', '500')}',
        '--reference-skill=${env('HEIR_AUDIT_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('HEIR_AUDIT_MAX_PLIES', '24')}',
        '--top-count=${env('HEIR_AUDIT_TOP_COUNT', '8')}',
        '--fen=${env('HEIR_AUDIT_FEN', '')}',
        '--moves=${env('HEIR_AUDIT_MOVES', '')}',
      ]);

      final reportFile = File(
        env('HEIR_AUDIT_REPORT_PATH', '/tmp/heir_engine_audit_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Worst'));
      expect(report, contains('Final status:'));
    },
    skip:
        'Manual Heir analysis harness; run with --run-skipped when auditing engine quality.',
  );
}
