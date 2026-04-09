import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/heir_position_probe.dart';

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

/// Hard Heir probe positions collected from audit outliers.
///
/// Heir shares Mercenary-style pawn rules plus king-capture win conditions.
/// These positions test the interaction between early king safety and the
/// Heir-specific promotion-to-king win path.
const _probeCases = [
  _ProbeCase(
    name: 'd4-d5 symmetric structure — avoid early king walk',
    moves: ['d2d4', 'd7d5', 'g1f3', 'g8f6', 'b1c3', 'b8c6', 'e2e3'],
    candidates: ['e1d2', 'f1e2', 'c1d2'],
  ),
  _ProbeCase(
    name: 'e4-e5 king engagement — timing of king advance',
    moves: ['e2e4', 'e7e5', 'g1f3', 'g8f6', 'b1c3', 'b8c6', 'd2d3'],
    candidates: ['e1e2', 'd1d2', 'f1e2'],
  ),
  _ProbeCase(
    name: 'pawn grab vs development — avoid greedy capture in c4 line',
    moves: [
      'c2c4',
      'e7e5',
      'b1c3',
      'g8f6',
      'g1f3',
      'b8c6',
      'd2d3',
      'f8c5',
      'e2e3',
    ],
    candidates: ['f3e5', 'f1e2', 'c1d2'],
  ),
  _ProbeCase(
    name: 'f4 bird opening — king visibility vs stability',
    moves: ['f2f4', 'e7e5', 'f4e5', 'd7d6', 'e5d6', 'c8d7', 'd6c7'],
    candidates: ['e1d2', 'e1e2', 'd1d4'],
  ),
];

void main() {
  test(
    'manual Heir probe bundle',
    () {
      final sections = <String>[];
      for (final probeCase in _probeCases) {
        sections.add('CASE: ${probeCase.name}');
        sections.add(
          runHeirPositionProbe([
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
      final reportFile = File('/tmp/heir_probe_cases_report.txt');
      reportFile.writeAsStringSync(report);

      expect(report, contains('CASE:'));
      expect(report, contains('Requested candidates:'));
    },
    skip:
        'Manual Heir debug bundle; run with --run-skipped when inspecting top baseline outliers.',
  );
}
