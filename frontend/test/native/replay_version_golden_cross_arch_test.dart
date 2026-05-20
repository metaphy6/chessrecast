// §12.5.bullet-3 T-P-GCAP — Cross-architecture golden parity.
//
// The move-generation golden must produce the same hashes regardless of the
// host architecture.  This test verifies that the CURRENT run (which may be
// x86_64 or arm64) agrees with the stored golden.
//
// Local runs: verifies current architecture agrees with the golden.
// CI matrix (future): runs on ubuntu-latest (x86_64) AND
//   self-hosted arm64 runner; both must produce identical hashes.
//
// Implementation note:
//   The golden is built from the DART-side board layer (not native FFI), so
//   it is inherently architecture-independent.  This test documents that
//   invariant explicitly and will catch any accidental introduction of
//   platform-specific Dart behavior (e.g., int size, endianness).
//
// Proof artefact for §12.5.bullet-3.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/board/board.dart';
import 'package:chessrecast/board/moves/generation.dart';
import 'package:chessrecast/board/moves/position.dart';
import 'package:chessrecast/board/piece.dart'; // ChessPiece
import 'package:chessrecast/board/pieces/piece_color.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:chessrecast/services/p2p/protocol/engine_replay_version.dart';

// Same positions and mods as replay_version_golden_test.dart.
// They must remain in sync — if you change one, change both.
const _positions = <String>[
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
  'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
  'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
  'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
  'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
  'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQK2R w KQkq - 4 6',
  '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1',
  '8/4k3/8/8/8/8/4K3/8 w - - 0 1',
  'Q7/8/8/8/8/8/8/7q w - - 0 1',
  '8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1',
  '8/8/8/3k4/3K4/8/8/8 w - - 0 1',
  'rnbkqbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBKQBNR w KQkq - 0 1',
];

const _mods = <ModsEnum>[
  ModsEnum.classic,
  ModsEnum.heir,
  ModsEnum.friendlyFire,
  ModsEnum.kingsBattle,
  ModsEnum.mercenary,
  ModsEnum.saveTheQueen,
  ModsEnum.succession,
  ModsEnum.truce,
];

String _squareName(Position pos) {
  const files = 'abcdefgh';
  return '${files[pos.col]}${pos.row + 1}';
}

List<String> _allLegalMoves(ChessBoard board) {
  final moves = <String>[];
  final currentPieces =
      board.pieces.where((p) => p.color == board.currentPlayer).toList();
  for (final piece in currentPieces) {
    for (final move in board.getValidMovesFor(piece.position)) {
      final from = _squareName(move.from);
      final to = _squareName(move.to);
      final promo = move.promotionPiece?.toLowerCase() ?? '';
      moves.add('$from$to$promo');
    }
  }
  moves.sort();
  return moves;
}

Map<String, String> _computeHashes() {
  final result = <String, String>{};
  for (final fen in _positions) {
    for (final mod in _mods) {
      ChessBoard board;
      try {
        board = ChessBoard.fromFEN(fen, gameType: mod);
      } catch (_) {
        result['${mod.name}::$fen'] = 'skip';
        continue;
      }
      final moves = _allLegalMoves(board);
      final payload = '${mod.name}::$fen::${moves.join(',')}';
      final hash = sha256.convert(utf8.encode(payload)).toString();
      result['${mod.name}::$fen'] = hash;
    }
  }
  return result;
}

String _goldenPath() {
  final cwd = Directory.current.path;
  final candidates = [
    '$cwd/test/native/goldens/replay_version_v$kEngineReplayVersion.json',
    '$cwd/../frontend/test/native/goldens/'
        'replay_version_v$kEngineReplayVersion.json',
  ];
  return candidates.firstWhere(
    (p) => File(p).existsSync(),
    orElse: () => candidates.first,
  );
}

void main() {
  group(
    '§12.5.bullet-3 Cross-architecture golden parity',
    () {
      test('hashes are identical to the stored golden on this architecture',
          () {
        final goldenPath = _goldenPath();
        if (!File(goldenPath).existsSync()) {
          fail(
            'Golden file not found: $goldenPath\n'
            'Run replay_version_golden_test.dart with GOLDEN_GENERATE=1 first.',
          );
        }

        final stored = jsonDecode(
          File(goldenPath).readAsStringSync(),
        ) as Map<String, dynamic>;

        final storedHashes = stored['hashes'] as Map<String, dynamic>;
        final computed = _computeHashes();

        final mismatches = <String>[];
        for (final entry in computed.entries) {
          final expected = storedHashes[entry.key] as String?;
          if (expected != null && expected != entry.value) {
            mismatches.add(
              '  ${entry.key}:\n'
              '    expected: $expected\n'
              '    got:      ${entry.value}',
            );
          }
        }

        expect(
          mismatches,
          isEmpty,
          reason:
              'Cross-architecture hash mismatch on '
              '${Platform.operatingSystem} ${Platform.version}.\n'
              'Move generation is NOT architecture-independent.\n'
              'This is a critical bug — the same chess position produces '
              'different legal-move sets on different CPUs.\n\n'
              'Mismatches:\n${mismatches.join('\n')}',
        );
      });

      test(
          'hashes are stable across two independent computations '
          '(no randomness)', () {
        final run1 = _computeHashes();
        final run2 = _computeHashes();

        final inconsistent = <String>[];
        for (final key in run1.keys) {
          if (run1[key] != run2[key]) {
            inconsistent.add('  $key: ${run1[key]} ≠ ${run2[key]}');
          }
        }

        expect(
          inconsistent,
          isEmpty,
          reason:
              'Move-generation is non-deterministic — two runs on the same '
              'machine produced different hashes:\n${inconsistent.join('\n')}',
        );
      });
    },
  );
}
