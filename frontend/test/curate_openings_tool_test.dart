import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/curate_openings.dart';

void main() {
  group('curate_openings tool', () {
    test('parses GAME status worst lines with report line numbers', () {
      final tmp = Directory.systemTemp.createTempSync('curate-openings-parse-');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });

      final report = File('${tmp.path}/report.txt')
        ..writeAsStringSync('''
GAME 1 e2e4,e7e5
status=ongoing after 24 plies worst=+0.09 played=a2-a4 ref=h2-h4
GAME 2 d2d4,d7d5
status=ongoing after 24 plies worst=+2.31 played=f2f4 ref=e2e4
''');

      final parsed = parseReportWorstSamples(
        report.path,
        reportPathOverride: 'bots/reports/truce/sample.txt',
      );

      expect(parsed.length, 2);
      expect(parsed['e2e4,e7e5']!.single.worst, closeTo(0.09, 0.0001));
      expect(parsed['e2e4,e7e5']!.single.line, 2);
      expect(parsed['d2d4,d7d5']!.single.worst, closeTo(2.31, 0.0001));
      expect(parsed['d2d4,d7d5']!.single.line, 4);
    });

    test('emits promote and demote candidates from a 3-report window', () {
      final root = Directory.systemTemp.createTempSync('curate-openings-root-');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });

      Directory('${root.path}/bots/baselines').createSync(recursive: true);
      Directory('${root.path}/bots/reports/truce').createSync(recursive: true);

      File('${root.path}/bots/baselines/truce.json').writeAsStringSync('''
{"mod":"truce","kpi":{"avgWorstMiss_cp":10}}
''');

      final reports = [
        File('${root.path}/bots/reports/truce/r1.txt'),
        File('${root.path}/bots/reports/truce/r2.txt'),
        File('${root.path}/bots/reports/truce/r3.txt'),
      ];

      reports[0].writeAsStringSync('''
GAME 1 easy-open
status=ongoing after 24 plies worst=+0.10 played=a2a3 ref=a2a4
GAME 2 hard-open
status=ongoing after 24 plies worst=+2.40 played=h2h3 ref=g2g4
''');
      reports[1].writeAsStringSync('''
GAME 1 easy-open
status=ongoing after 24 plies worst=+0.20 played=a2a3 ref=a2a4
GAME 2 hard-open
status=ongoing after 24 plies worst=+2.10 played=h2h3 ref=g2g4
''');
      reports[2].writeAsStringSync('''
GAME 1 easy-open
status=ongoing after 24 plies worst=+0.30 played=a2a3 ref=a2a4
GAME 2 hard-open
status=ongoing after 24 plies worst=+1.70 played=h2h3 ref=g2g4
''');

      final options = CurateOptions(
        reportWindow: 3,
        recurringReports: 2,
        demoteWorstLt: 0.5,
        promoteWorstGte: 2.0,
      );

      final plan = buildModPlan(root.path, 'truce', options);

      final actions = {
        for (final proposal in plan.proposals)
          proposal.opening: proposal.action,
      };

      expect(actions['easy-open'], 'demote_to_discovery');
      expect(actions['hard-open'], 'promote_to_stress');

      final yaml = renderYamlPlan([plan], options);
      expect(yaml, contains('queue_entries:'));
      expect(yaml, contains('truce-corpus-curation-promote-'));
      expect(yaml, contains('truce-corpus-curation-demote-'));
    });
  });
}
