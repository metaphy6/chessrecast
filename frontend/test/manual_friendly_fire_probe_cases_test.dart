import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/friendly_fire_position_probe.dart';

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
    name: 'd4-d5 Bf1-e2 vs king walk — prefer development',
    moves: [
      'd2d4',
      'd7d5',
      'g1f3',
      'g8f6',
      'b1c3',
      'b8c6',
      'c1f4',
      'h7h6',
      'c3b5',
      'e7e5',
      'f3e5',
      'c6e7',
      'e5c6',
      'e7c6',
      'b5c7',
      'e8d7',
      'c7a8',
      'f8d6',
      'e2e3',
      'd6f4',
      'e3f4',
      'd8e8',
    ],
    candidates: ['e1d2', 'f1e2'],
  ),
  _ProbeCase(
    name: 'g4-e5 h4-g4 queen pressure — prefer rook defence',
    moves: [
      'g2g4',
      'e7e5',
      'b1c3',
      'd7d5',
      'd2d4',
      'b8c6',
      'e2e3',
      'c8e6',
      'f1b5',
      'g8f6',
      'b5c6',
      'b7c6',
      'd4e5',
      'f6e4',
      'g1e2',
      'd8h4',
      'c3e4',
      'd5e4',
      'd1d4',
      'h4g4',
      'e2c3',
      'e6f5',
      'c1d2',
      'g4g2',
    ],
    candidates: ['d4e5', 'h1f1'],
  ),
  _ProbeCase(
    name: 'c5-a5 queen sortie — prefer a3xb4 recapture',
    moves: [
      'd2d4',
      'c7c5',
      'd4c5',
      'e7e5',
      'c1e3',
      'b8c6',
      'g1f3',
      'g8f6',
      'b1c3',
      'd8a5',
      'a2a3',
      'f6e4',
      'b2b4',
      'c6b4',
    ],
    candidates: ['e3d2', 'a3b4'],
  ),
  _ProbeCase(
    name: 'f5 gambit Qd8xd5 vs e4xd5 — prefer queen recapture',
    moves: [
      'd2d4',
      'c7c5',
      'g1f3',
      'c5d4',
      'f3d4',
      'g8f6',
      'b1c3',
      'e7e5',
      'd4f3',
      'b8c6',
      'e2e4',
      'f8c5',
      'f1c4',
      'd8b6',
      'c3d5',
      'f6d5',
    ],
    candidates: ['e4d5', 'd1d5'],
  ),
  _ProbeCase(
    name: 'b4-e7 vs king tuck in b4-e5 — prefer bishop development',
    moves: [
      'b2b4',
      'e7e5',
      'b4b5',
      'g8f6',
      'b1c3',
      'd7d5',
      'd2d4',
      'f8b4',
      'c1b2',
      'f6e4',
      'd1d3',
      'd8f6',
      'g1f3',
      'e5d4',
      'f3d4',
      'b8d7',
      'f2f3',
      'f6h4',
      'g2g3',
      'e4g3',
      'd3e3',
      'e8f8',
      'e3f2',
    ],
    candidates: ['f8g8', 'b4e7'],
  ),
];

void main() {
  test(
    'manual Friendly Fire probe bundle',
    () {
      final sections = <String>[];
      for (final probeCase in _probeCases) {
        sections.add('CASE: ${probeCase.name}');
        sections.add(
          runFriendlyFirePositionProbe([
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
      final reportFile = File('/tmp/friendly_fire_probe_cases_report.txt');
      reportFile.writeAsStringSync(report);

      expect(report, contains('CASE:'));
      expect(report, contains('Requested candidates:'));
    },
    skip:
        'Manual Friendly Fire debug bundle; run with --run-skipped when inspecting top baseline outliers.',
  );
}
