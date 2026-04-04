import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/friendly_fire_engine_audit.dart';

void main() {
  test(
    'manual Friendly Fire native-engine audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runFriendlyFireAudit([
        '--baseline-depth=${env('FRIENDLY_FIRE_AUDIT_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('FRIENDLY_FIRE_AUDIT_BASELINE_MS', '120')}',
        '--baseline-skill=${env('FRIENDLY_FIRE_AUDIT_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('FRIENDLY_FIRE_AUDIT_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('FRIENDLY_FIRE_AUDIT_REFERENCE_MS', '500')}',
        '--reference-skill=${env('FRIENDLY_FIRE_AUDIT_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('FRIENDLY_FIRE_AUDIT_MAX_PLIES', '24')}',
        '--top-count=${env('FRIENDLY_FIRE_AUDIT_TOP_COUNT', '8')}',
        '--fen=${env('FRIENDLY_FIRE_AUDIT_FEN', '')}',
        '--moves=${env('FRIENDLY_FIRE_AUDIT_MOVES', '')}',
      ]);

      final reportFile = File(
        env(
          'FRIENDLY_FIRE_AUDIT_REPORT_PATH',
          '/tmp/friendly_fire_engine_audit_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Worst'));
      expect(report, contains('Final status:'));
    },
    skip:
        'Manual Friendly Fire analysis harness; run with --run-skipped when auditing engine quality.',
  );
}
