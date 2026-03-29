import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/truce_preset_calibration.dart';

void main() {
  test(
    'manual Truce preset calibration',
    () {
      String env(String name, String fallback) =>
          Platform.environment[name] ?? fallback;

      final report = runTrucePresetCalibration([
        '--suite=${env('TRUCE_PRESET_SUITE', 'production')}',
        '--levels=${env('TRUCE_PRESET_LEVELS', '')}',
        '--reference-depth=${env('TRUCE_PRESET_REFERENCE_DEPTH', '12')}',
        '--reference-ms=${env('TRUCE_PRESET_REFERENCE_MS', '4000')}',
        '--reference-skill=${env('TRUCE_PRESET_REFERENCE_SKILL', '4')}',
        '--top-count=${env('TRUCE_PRESET_TOP_COUNT', '5')}',
      ]);

      final reportFile = File(
        env(
          'TRUCE_PRESET_REPORT_PATH',
          '/tmp/truce_preset_calibration_report.txt',
        ),
      );
      reportFile.writeAsStringSync(report);

      expect(report, contains('Summary:'));
      expect(report, contains('avg miss'));
    },
    skip:
        'Manual Truce preset calibration; run with --run-skipped when measuring app EngineLevel quality.',
  );
}
