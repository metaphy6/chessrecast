import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/mercenary_engine_audit.dart';

void main() {
  test(
    'manual Mercenary native-engine audit',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runMercenaryAudit([
        '--baseline-depth=${env('MERC_AUDIT_BASELINE_DEPTH', '4')}',
        '--baseline-ms=${env('MERC_AUDIT_BASELINE_MS', '120')}',
        '--baseline-skill=${env('MERC_AUDIT_BASELINE_SKILL', '4')}',
        '--reference-depth=${env('MERC_AUDIT_REFERENCE_DEPTH', '6')}',
        '--reference-ms=${env('MERC_AUDIT_REFERENCE_MS', '500')}',
        '--reference-skill=${env('MERC_AUDIT_REFERENCE_SKILL', '4')}',
        '--max-plies=${env('MERC_AUDIT_MAX_PLIES', '24')}',
        '--top-count=${env('MERC_AUDIT_TOP_COUNT', '8')}',
        '--fen=${env('MERC_AUDIT_FEN', '')}',
        '--moves=${env('MERC_AUDIT_MOVES', '')}',
      ]);

      final reportFile = File(
        env('MERC_AUDIT_REPORT_PATH', '/tmp/mercenary_engine_audit_report.txt'),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Worst'));
      expect(report, contains('Final status:'));
    },
    skip:
        'Manual Mercenary analysis harness; run with --run-skipped when auditing engine quality.',
  );
}
