import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

const _modsUnderKingDiscipline = <ModsEnum>[
  ModsEnum.heir,
  ModsEnum.mercenary,
  ModsEnum.saveTheQueen,
  ModsEnum.succession,
];

const _scenarios = <_KingPolicyScenario>[
  _KingPolicyScenario(
    name: 'avoids early king drift with castling rights (white to move)',
    fen: 'r3k2r/ppp2ppp/2n1bn2/3pp3/3PP3/2N1BN2/PPP2PPP/R3K2R w KQkq - 0 8',
  ),
  _KingPolicyScenario(
    name: 'avoids early king drift with castling rights (black to move)',
    fen: 'r3k2r/ppp2ppp/2n1bn2/3pp3/3PP3/2N1BN2/PPP2PPP/R3K2R b KQkq - 0 8',
  ),
];

void main() {
  group('King/castling policy native regression', () {
    for (final mod in _modsUnderKingDiscipline) {
      for (final scenario in _scenarios) {
        test('${mod.displayName} ${scenario.name}', () {
          final board = ChessBoard.fromFEN(scenario.fen, gameType: mod);
          final legalMoves = Orchestrator().getAllValidMoves(board);
          final hasCastling = legalMoves.any(_isCastlingMove);
          final hasQuietKingMove = legalMoves.any(_isQuietNonCastlingKingMove);

          expect(hasCastling, isTrue);
          expect(hasQuietKingMove, isTrue);

          final result = NativeEngine().findBestMoveSync(
            board,
            timeLimitMs: 1200,
            maxDepth: 7,
            skillLevel: 6,
          );

          final bestMove = result.bestMove;
          expect(bestMove, isNotNull);
          expect(
            _isQuietNonCastlingKingMove(bestMove!),
            isFalse,
            reason:
                'best=${_moveNotation(bestMove)}, score=${result.score}, mod=${mod.name}',
          );
        }, skip: !NativeEngine.isAvailable);
      }
    }
  });
}

class _KingPolicyScenario {
  final String name;
  final String fen;

  const _KingPolicyScenario({required this.name, required this.fen});
}

bool _isCastlingMove(ChessMove move) {
  return move.piece.type.name == 'king' && move.isCastling;
}

bool _isQuietNonCastlingKingMove(ChessMove move) {
  if (move.piece.type.name != 'king') return false;
  if (move.isCastling) return false;
  if (move.isCapture || move.isEnPassant || move.isPromotion) return false;
  return true;
}

String _moveNotation(ChessMove move) {
  return '${move.from.algebraic}${move.to.algebraic}';
}
