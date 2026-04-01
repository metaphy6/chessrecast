import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/kings_battle_engine_audit.dart';

const _kbAuditBaselineDepth = String.fromEnvironment('KB_AUDIT_BASELINE_DEPTH');
const _kbAuditBaselineMs = String.fromEnvironment('KB_AUDIT_BASELINE_MS');
const _kbAuditBaselineSkill = String.fromEnvironment('KB_AUDIT_BASELINE_SKILL');
const _kbAuditReferenceDepth = String.fromEnvironment(
  'KB_AUDIT_REFERENCE_DEPTH',
);
const _kbAuditReferenceMs = String.fromEnvironment('KB_AUDIT_REFERENCE_MS');
const _kbAuditReferenceSkill = String.fromEnvironment(
  'KB_AUDIT_REFERENCE_SKILL',
);
const _kbAuditMaxPlies = String.fromEnvironment('KB_AUDIT_MAX_PLIES');
const _kbAuditTopCount = String.fromEnvironment('KB_AUDIT_TOP_COUNT');
const _kbAuditFen = String.fromEnvironment('KB_AUDIT_FEN');
const _kbAuditMoves = String.fromEnvironment('KB_AUDIT_MOVES');
const _kbAuditReportPath = String.fromEnvironment('KB_AUDIT_REPORT_PATH');

void main() {
  test(
    'manual Kings Battle native-engine audit',
    () {
      String setting(String name, String fallback, String defineValue) {
        final envValue = Platform.environment[name];
        if (envValue != null && envValue.isNotEmpty) {
          return envValue;
        }
        if (defineValue.isNotEmpty) {
          return defineValue;
        }
        return fallback;
      }

      final report = runKingsBattleAudit([
        '--baseline-depth=${setting('KB_AUDIT_BASELINE_DEPTH', '4', _kbAuditBaselineDepth)}',
        '--baseline-ms=${setting('KB_AUDIT_BASELINE_MS', '150', _kbAuditBaselineMs)}',
        '--baseline-skill=${setting('KB_AUDIT_BASELINE_SKILL', '4', _kbAuditBaselineSkill)}',
        '--reference-depth=${setting('KB_AUDIT_REFERENCE_DEPTH', '6', _kbAuditReferenceDepth)}',
        '--reference-ms=${setting('KB_AUDIT_REFERENCE_MS', '600', _kbAuditReferenceMs)}',
        '--reference-skill=${setting('KB_AUDIT_REFERENCE_SKILL', '4', _kbAuditReferenceSkill)}',
        '--max-plies=${setting('KB_AUDIT_MAX_PLIES', '40', _kbAuditMaxPlies)}',
        '--top-count=${setting('KB_AUDIT_TOP_COUNT', '8', _kbAuditTopCount)}',
        '--fen=${setting('KB_AUDIT_FEN', '', _kbAuditFen)}',
        '--moves=${setting('KB_AUDIT_MOVES', '', _kbAuditMoves)}',
      ]);

      final reportFile = File(
        setting(
          'KB_AUDIT_REPORT_PATH',
          '/tmp/kings_battle_engine_audit_report.txt',
          _kbAuditReportPath,
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Worst'));
      expect(report, contains('Final status:'));
    },
    skip:
        'Manual Kings Battle analysis harness; run with --run-skipped when auditing engine quality.',
  );
}
