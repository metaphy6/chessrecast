import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/kings_battle_position_probe.dart';

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

const _probeCases = [
  _ProbeCase(
    name: 'early king activation over c7c6',
    moves: ['d2d3', 'e7e5', 'e1d2'],
    candidates: ['e8e7', 'c7c6'],
  ),
  _ProbeCase(
    name: 'catastrophic b4-f5 line',
    moves: [
      'b2b4',
      'f7f5',
      'c2c3',
      'e8f7',
      'g2g3',
      'f7e6',
      'f2f4',
      'e6d5',
      'e1f2',
      'd5e4',
    ],
    candidates: ['d2d3', 'c3c4'],
  ),
  _ProbeCase(
    name: 'capture c5 instead of h-pawn push',
    moves: [
      'd2d3',
      'c7c5',
      'e1d2',
      'd7d6',
      'd2c3',
      'b7b5',
      'e2e4',
      'e8d7',
      'g2g3',
      'd7e6',
      'b2b4',
      'g7g6',
      'b4c5',
    ],
    candidates: ['h7h5', 'd6c5'],
  ),
  _ProbeCase(
    name: 'prefer c4-c3 over c4xd3',
    moves: [
      'e2e3',
      'c7c5',
      'e1e2',
      'c5c4',
      'e2f3',
      'd7d5',
      'f3f4',
      'e7e5',
      'f4f3',
      'e8e7',
      'b2b3',
      'e7d6',
      'd2d3',
      'e5e4',
      'f3f4',
      'g7g5',
      'f4g3',
      'e4d3',
      'c2d3',
    ],
    candidates: ['c4d3', 'c4c3'],
  ),
  _ProbeCase(
    name: 'game 28 prefer g4-g3 over g4xf3',
    moves: [
      'g2g4',
      'f7f5',
      'f2f3',
      'e8f7',
      'e1f2',
      'f7f6',
      'f2e3',
      'e7e6',
      'd2d4',
      'c7c6',
      'b2b3',
      'd7d5',
      'a2a4',
      'h7h5',
      'a4a5',
      'f5f4',
      'e3d3',
      'a7a6',
      'b3b4',
      'h5g4',
      'c2c3',
    ],
    candidates: ['g4f3', 'g4g3'],
  ),
  _ProbeCase(
    name: 'game 2 prefer e5-e4 over d5-d4',
    moves: [
      'e2e4',
      'd7d5',
      'e1e2',
      'e8d7',
      'e2d3',
      'd7c6',
      'g2g3',
      'f7f6',
      'f2f4',
      'b7b6',
      'a2a3',
      'c6d6',
      'b2b3',
      'a7a5',
      'a3a4',
      'd6c5',
      'e4e5',
      'f6e5',
      'f4f5',
      'c5b4',
      'g3g4',
      'h7h6',
      'h2h4',
      'e7e6',
      'f5e6',
    ],
    candidates: ['d5d4', 'e5e4'],
  ),
  _ProbeCase(
    name: 'game 44 prefer Bf1-g2 over h2-h3',
    moves: [
      'f2f3',
      'c7c5',
      'e1f2',
      'd7d6',
      'f2e3',
      'e8d7',
      'e3e4',
      'd7e6',
      'g2g3',
      'd6d5',
      'e4d3',
      'b7b6',
      'b2b3',
      'e6e5',
      'f3f4',
      'e5f5',
      'g3g4',
      'f5f4',
      'c8g4',
      'e2e3',
      'f4g5',
      'g1f3',
      'g5h6',
      'b1c3',
      'e7e5',
    ],
    candidates: ['h2h3', 'f1g2'],
  ),
  _ProbeCase(
    name: 'game 34 central continuation over g7-g5',
    moves: [
      'e2e3',
      'c7c5',
      'e1e2',
      'c5c4',
      'e2f3',
      'd7d5',
      'f3f4',
      'e7e5',
      'f4f3',
      'e8e7',
      'd2d3',
      'e7d6',
      'h2h4',
      'e5e4',
      'f3f4',
    ],
    candidates: ['g7g5', 'c4d3', 'c4c3'],
  ),
];

void main() {
  test(
    'manual Kings Battle probe bundle',
    () {
      final sections = <String>[];
      for (final probeCase in _probeCases) {
        sections.add('CASE: ${probeCase.name}');
        sections.add(
          runKingsBattlePositionProbe([
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
      final reportFile = File('/tmp/kings_battle_probe_cases_report.txt');
      reportFile.writeAsStringSync(report);

      expect(report, contains('CASE:'));
      expect(report, contains('Requested candidates:'));
    },
    skip:
        'Manual Kings Battle debug bundle; run with --run-skipped when inspecting top baseline outliers.',
  );
}
