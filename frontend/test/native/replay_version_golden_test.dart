// §12.3.stability T-P-GOLDEN — Move-generation determinism golden test.
//
// Records a SHA-256 hash of sorted legal-move lists for a representative set
// of board positions × all 7 mods.  The hash is stored in
// frontend/test/native/goldens/replay_version_v<N>.json where N is
// kEngineReplayVersion.
//
// If ENGINE_REPLAY_VERSION is bumped, the old golden file becomes invalid
// (different key) and the developer must run with GOLDEN_GENERATE=1 to
// regenerate it.
//
// Pre-implementation (failing) state:
//   goldens/replay_version_v1.json does not exist → test fails.
//
// Post-generation (passing) state:
//   Golden file exists and hashes match.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chessrecast/board/board.dart';
import 'package:chessrecast/board/moves/generation.dart';
import 'package:chessrecast/board/moves/position.dart';
import 'package:chessrecast/board/piece.dart';  // ChessPiece
import 'package:chessrecast/mods/enums.dart';
import 'package:chessrecast/board/pieces/piece_color.dart';
import 'package:chessrecast/services/p2p/protocol/engine_replay_version.dart';

// ---------------------------------------------------------------------------
// Representative board positions for the golden.
//
// Rule: positions must be deterministic, cover all phases, and touch mod-
// specific rule paths for each of the 7 mods.
// ---------------------------------------------------------------------------

const _positions = <String>[
  // Standard opening positions
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
  'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
  'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
  'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
  'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
  // Mid-game with active pieces (Friendly Fire / Kings Battle territory)
  'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQK2R w KQkq - 4 6',
  // Endgame positions
  '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1',
  '8/4k3/8/8/8/8/4K3/8 w - - 0 1',
  // Position with queens (Save the Queen territory)
  'Q7/8/8/8/8/8/8/7q w - - 0 1',
  // Position with paired pawns (Mercenary / Succession territory)
  '8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1',
  // Kings central (Kings Battle territory)
  '8/8/8/3k4/3K4/8/8/8 w - - 0 1',
  // Heir mod: position with multiple kings
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

// ---------------------------------------------------------------------------
// Hash computation
// ---------------------------------------------------------------------------

/// Returns sorted canonical UCI moves from [board] for all current-player
/// pieces, formatted as '<from><to>[promotion]'.
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

String _squareName(Position pos) {
  const files = 'abcdefgh';
  return '${files[pos.col]}${pos.row + 1}';
}

/// Compute SHA-256 hex over all positions × mods.
Map<String, String> _computeHashes() {
  final result = <String, String>{};

  for (final fen in _positions) {
    for (final mod in _mods) {
      ChessBoard board;
      try {
        board = ChessBoard.fromFEN(fen, gameType: mod);
      } catch (_) {
        // Some mods may reject certain FENs (e.g. Succession with too many
        // pieces).  Record 'skip' so the golden doesn't change on mod updates.
        result['${mod.name}::$fen'] = 'skip';
        continue;
      }

      final moves = _allLegalMoves(board);
      final payload = '${mod.name}::$fen::${moves.join(',')}';
      final hash =
          sha256.convert(utf8.encode(payload)).toString();
      result['${mod.name}::$fen'] = hash;
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Golden file helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const generateEnv = 'GOLDEN_GENERATE';

  group(
    '§12.3.stability ENGINE_REPLAY_VERSION move-gen golden',
    () {
      late String goldenPath;
      late bool shouldGenerate;

      setUpAll(() {
        goldenPath = _goldenPath();
        shouldGenerate =
            Platform.environment[generateEnv]?.isNotEmpty == true;
      });

      test('golden file exists for current ENGINE_REPLAY_VERSION', () {
        if (shouldGenerate) {
          // Generation mode — skip existence check.
          return;
        }
        expect(
          File(goldenPath).existsSync(),
          isTrue,
          reason:
              'Golden file not found: $goldenPath\n'
              'Run with GOLDEN_GENERATE=1 to generate it:\n'
              '  GOLDEN_GENERATE=1 flutter test '
              'test/native/replay_version_golden_test.dart',
        );
      });

      test('generate golden (only when GOLDEN_GENERATE=1)', () {
        if (!shouldGenerate) return; // normal mode — skip

        final hashes = _computeHashes();
        final json = const JsonEncoder.withIndent('  ').convert({
          'engine_replay_version': kEngineReplayVersion,
          'generated_at': DateTime.now().toUtc().toIso8601String(),
          'positions': _positions.length,
          'mods': _mods.map((m) => m.name).toList(),
          'hashes': hashes,
        });

        final dir = File(goldenPath).parent;
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File(goldenPath).writeAsStringSync(json);
        // ignore: avoid_print
        print('Golden generated: $goldenPath');
      });

      test('hashes match golden', () {
        if (shouldGenerate) return; // generation mode — skip comparison
        if (!File(goldenPath).existsSync()) {
          fail(
            'Golden file not found: $goldenPath — '
            'run with GOLDEN_GENERATE=1 first.',
          );
        }

        final stored = jsonDecode(
          File(goldenPath).readAsStringSync(),
        ) as Map<String, dynamic>;

        final storedVersion = stored['engine_replay_version'] as int;
        expect(
          storedVersion,
          equals(kEngineReplayVersion),
          reason:
              'Golden was generated for ENGINE_REPLAY_VERSION=$storedVersion '
              'but kEngineReplayVersion=$kEngineReplayVersion. '
              'Bump ENGINE_REPLAY_VERSION and regenerate the golden.',
        );

        final storedHashes = stored['hashes'] as Map<String, dynamic>;
        final computedHashes = _computeHashes();

        final mismatches = <String>[];
        for (final entry in computedHashes.entries) {
          final expected = storedHashes[entry.key] as String?;
          if (expected == null) {
            mismatches.add('  ${entry.key}: NEW (not in golden)');
          } else if (expected != entry.value) {
            mismatches.add('  ${entry.key}: expected $expected got ${entry.value}');
          }
        }

        // Also check for keys in golden that no longer exist in computed.
        for (final key in storedHashes.keys) {
          if (!computedHashes.containsKey(key)) {
            mismatches.add('  $key: DELETED (in golden but not computed)');
          }
        }

        expect(
          mismatches,
          isEmpty,
          reason:
              'Move-generation golden mismatch — rule semantics changed!\n'
              'If intentional, bump ENGINE_REPLAY_VERSION in replay_version.h '
              'and engine_replay_version.dart, then regenerate with:\n'
              '  GOLDEN_GENERATE=1 flutter test '
              'test/native/replay_version_golden_test.dart\n\n'
              'Mismatches:\n${mismatches.join('\n')}',
        );
      });
    },
  );
}
