import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/mercenary_position_probe.dart';

class _ProbeCase {
  final String name;
  final List<String> moves;
  final List<String> candidates;

  const _ProbeCase({
    required this.name,
    required this.moves,
    required this.candidates,
  });
}

/// Mercenary positions from audit outliers.
///
/// Key dynamics to probe:
/// - Pawn delta (8-directional pawns create unusual pawn chains)
/// - No-promotion constraint means late-game pawn imbalances differ from classical
/// - King exposure is amplified because pawns can attack sideways and backward
const _probeCases = [
  _ProbeCase(
    name: 'd4-d5 standard setup — pawn lateral control',
    moves: ['d2d4', 'd7d5', 'b1c3', 'b8c6', 'g1f3', 'g8f6', 'e2e3'],
    candidates: ['c1d2', 'f1e2', 'e3e4'],
  ),
  _ProbeCase(
    name: 'e4-e5 knight dance — avoid pawn-king collision',
    moves: ['e2e4', 'e7e5', 'g1f3', 'g8f6', 'b1c3', 'b8c6', 'f1c4'],
    candidates: ['f6e4', 'd7d6', 'd7d5'],
  ),
  _ProbeCase(
    name: 'pawn cluster at c4-d5 — diagonal break timing',
    moves: ['c2c4', 'd7d5', 'd2d4', 'e7e5', 'c4d5', 'e5d4', 'g1f3'],
    candidates: ['d4d3', 'g8f6', 'b8c6'],
  ),
  _ProbeCase(
    name: 'king-side pawn storm — h4 push vs development',
    moves: ['g2g4', 'e7e5', 'b1c3', 'b8c6', 'f1g2', 'f8c5', 'g1f3'],
    candidates: ['h2h4', 'e2e3', 'd2d3'],
  ),
];

void main() {
  test(
    'manual Mercenary probe bundle',
    () {
      final sections = <String>[];
      for (final probeCase in _probeCases) {
        sections.add('CASE: ${probeCase.name}');
        sections.add(
          runMercenaryPositionProbe([
            '--moves=${probeCase.moves.join(',')}',
            '--depth=6',
            '--time-ms=500',
            '--top-count=10',
            '--candidates=${probeCase.candidates.join(',')}',
          ]),
        );
        sections.add('');
      }

      final report = sections.join('\n');
      final reportFile = File('/tmp/mercenary_probe_cases_report.txt');
      reportFile.writeAsStringSync(report);

      expect(report, contains('CASE:'));
      expect(report, contains('Requested candidates:'));
    },
    skip:
        'Manual Mercenary debug bundle; run with --run-skipped when inspecting top baseline outliers.',
  );
}
