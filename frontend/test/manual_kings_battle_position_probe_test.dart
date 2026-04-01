import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/kings_battle_position_probe.dart';

const _kbProbeFen = String.fromEnvironment('KB_PROBE_FEN');
const _kbProbeMoves = String.fromEnvironment('KB_PROBE_MOVES');
const _kbProbeDepth = String.fromEnvironment('KB_PROBE_DEPTH');
const _kbProbeTimeMs = String.fromEnvironment('KB_PROBE_TIME_MS');
const _kbProbeSkill = String.fromEnvironment('KB_PROBE_SKILL');
const _kbProbeTopCount = String.fromEnvironment('KB_PROBE_TOP_COUNT');
const _kbProbeCandidates = String.fromEnvironment('KB_PROBE_CANDIDATES');
const _kbProbeReportPath = String.fromEnvironment('KB_PROBE_REPORT_PATH');

void main() {
  test(
    'manual Kings Battle position probe',
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

      final report = runKingsBattlePositionProbe([
        '--fen=${setting('KB_PROBE_FEN', '', _kbProbeFen)}',
        '--moves=${setting('KB_PROBE_MOVES', '', _kbProbeMoves)}',
        '--depth=${setting('KB_PROBE_DEPTH', '6', _kbProbeDepth)}',
        '--time-ms=${setting('KB_PROBE_TIME_MS', '1200', _kbProbeTimeMs)}',
        '--skill=${setting('KB_PROBE_SKILL', '4', _kbProbeSkill)}',
        '--top-count=${setting('KB_PROBE_TOP_COUNT', '8', _kbProbeTopCount)}',
        '--candidates=${setting('KB_PROBE_CANDIDATES', '', _kbProbeCandidates)}',
      ]);

      final reportFile = File(
        setting(
          'KB_PROBE_REPORT_PATH',
          '/tmp/kings_battle_position_probe_report.txt',
          _kbProbeReportPath,
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Top'));
    },
    skip:
        'Manual Kings Battle position probe; run with --run-skipped when analyzing a specific position.',
  );
}
