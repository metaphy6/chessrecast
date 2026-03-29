import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/truce_engine_audit.dart';

void main() {
  test(
    'manual Truce native-engine audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runTruceAudit([
        '--baseline-depth=${env('TRUCE_AUDIT_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('TRUCE_AUDIT_BASELINE_MS', '150')}',
        '--baseline-skill=${env('TRUCE_AUDIT_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('TRUCE_AUDIT_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('TRUCE_AUDIT_REFERENCE_MS', '600')}',
        '--reference-skill=${env('TRUCE_AUDIT_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('TRUCE_AUDIT_MAX_PLIES', '40')}',
        '--top-count=${env('TRUCE_AUDIT_TOP_COUNT', '8')}',
        '--fen=${env('TRUCE_AUDIT_FEN', '')}',
        '--moves=${env('TRUCE_AUDIT_MOVES', '')}',
      ]);

      final reportFile = File(
        env('TRUCE_AUDIT_REPORT_PATH', '/tmp/truce_engine_audit_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Worst'));
      expect(report, contains('Final status:'));
    },
    skip:
        'Manual Truce analysis harness; run with --run-skipped when auditing engine quality.',
  );
}
