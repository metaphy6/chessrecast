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
        '--baseline-depth=${env('MERC_AUDIT_BASELINE_DEPTH', '3')}',
        '--baseline-ms=${env('MERC_AUDIT_BASELINE_MS', '100')}',
        '--reference-depth=${env('MERC_AUDIT_REFERENCE_DEPTH', '5')}',
        '--reference-ms=${env('MERC_AUDIT_REFERENCE_MS', '600')}',
        '--max-plies=${env('MERC_AUDIT_MAX_PLIES', '20')}',
        '--top-count=${env('MERC_AUDIT_TOP_COUNT', '5')}',
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
