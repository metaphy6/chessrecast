import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/kings_battle_audit_batch.dart';

const _kbBatchBaselineDepth = String.fromEnvironment('KB_BATCH_BASELINE_DEPTH');
const _kbBatchBaselineMs = String.fromEnvironment('KB_BATCH_BASELINE_MS');
const _kbBatchBaselineSkill = String.fromEnvironment('KB_BATCH_BASELINE_SKILL');
const _kbBatchReferenceDepth = String.fromEnvironment(
  'KB_BATCH_REFERENCE_DEPTH',
);
const _kbBatchReferenceMs = String.fromEnvironment('KB_BATCH_REFERENCE_MS');
const _kbBatchReferenceSkill = String.fromEnvironment(
  'KB_BATCH_REFERENCE_SKILL',
);
const _kbBatchMaxPlies = String.fromEnvironment('KB_BATCH_MAX_PLIES');
const _kbBatchTopCount = String.fromEnvironment('KB_BATCH_TOP_COUNT');
const _kbBatchOpenings = String.fromEnvironment('KB_BATCH_OPENINGS');
const _kbBatchStopAtDelta = String.fromEnvironment('KB_BATCH_STOP_AT_DELTA');
const _kbBatchReportPath = String.fromEnvironment('KB_BATCH_REPORT_PATH');

void main() {
  test(
    'manual Kings Battle batch audit',
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

      final args = [
        '--baseline-depth=${setting('KB_BATCH_BASELINE_DEPTH', '4', _kbBatchBaselineDepth)}',
        '--baseline-ms=${setting('KB_BATCH_BASELINE_MS', '120', _kbBatchBaselineMs)}',
        '--baseline-skill=${setting('KB_BATCH_BASELINE_SKILL', '4', _kbBatchBaselineSkill)}',
        '--reference-depth=${setting('KB_BATCH_REFERENCE_DEPTH', '6', _kbBatchReferenceDepth)}',
        '--reference-ms=${setting('KB_BATCH_REFERENCE_MS', '500', _kbBatchReferenceMs)}',
        '--reference-skill=${setting('KB_BATCH_REFERENCE_SKILL', '4', _kbBatchReferenceSkill)}',
        '--max-plies=${setting('KB_BATCH_MAX_PLIES', '24', _kbBatchMaxPlies)}',
        '--top-count=${setting('KB_BATCH_TOP_COUNT', '10', _kbBatchTopCount)}',
        '--openings=${setting('KB_BATCH_OPENINGS', '', _kbBatchOpenings)}',
      ];

      final stopAtDelta = setting(
        'KB_BATCH_STOP_AT_DELTA',
        '',
        _kbBatchStopAtDelta,
      ).trim();
      if (stopAtDelta.isNotEmpty) {
        args.add('--stop-at-delta=$stopAtDelta');
      }

      final report = runKingsBattleAuditBatch(args);

      final reportFile = File(
        setting(
          'KB_BATCH_REPORT_PATH',
          '/tmp/kings_battle_audit_batch_report.txt',
          _kbBatchReportPath,
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Aggregate:'));
      expect(report, contains('Worst openings:'));
    },
    skip:
        'Manual Kings Battle batch audit; run with --run-skipped when comparing opening suites.',
  );
}
