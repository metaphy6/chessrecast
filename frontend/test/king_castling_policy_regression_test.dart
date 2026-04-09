import 'package:chessrecast/board/utils/exporter.dart';
import 'package:chessrecast/engine/native.dart';
import 'package:chessrecast/management/orchestrator.dart';
import 'package:chessrecast/mods/enums.dart';
import 'package:flutter_test/flutter_test.dart';

const _modsUnderKingDiscipline = <ModsEnum>[
  ModsEnum.friendlyFire,
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
  _KingPolicyScenario(
    name: 'keeps castling rights under center pressure (white to move)',
    fen: 'r3k2r/ppp2ppp/2n1bn2/3q4/3PP3/2N1BN2/PPP2PPP/R3K2R w KQkq - 0 10',
  ),
  _KingPolicyScenario(
    name: 'keeps castling rights under center pressure (black to move)',
    fen: 'r3k2r/ppp2ppp/2n1bn2/3Q4/3pp3/2N1BN2/PPP2PPP/R3K2R b KQkq - 0 10',
  ),
  // Asymmetric: only white retains both castling rights; black a-rook already moved
  _KingPolicyScenario(
    name: 'retains castling rights when only one side has them (white to move)',
    fen: 'r3k2r/ppp2ppp/2n1bn2/3pp3/3PP3/2N1BN2/PPP2PPP/R3K2R w KQ - 0 8',
  ),
  // Semi-open center: d-file open, both sides have full rights
  _KingPolicyScenario(
    name:
        'prefers castling over king walk with semi-open center (white to move)',
    fen: 'r3k2r/ppp2ppp/2n2n2/3b4/3P4/2N2N2/PPP2PPP/R3K2R w KQkq - 0 9',
  ),
  // Tactical threat: enemy queen on h4 pressures f2; side-step must keep rights
  _KingPolicyScenario(
    name: 'keeps castling rights under queen pressure on h4 (white to move)',
    fen: 'r3k2r/ppp2ppp/2n1bn2/3pp3/7q/2N1BN2/PPP2PPP/R3K2R w KQkq - 0 8',
  ),
];

void main() {
  group('King/castling policy native regression', () {
    for (final mod in _modsUnderKingDiscipline) {
      for (final scenario in _scenarios) {
        test('${mod.displayName} ${scenario.name}', () {
          final board = ChessBoard.fromFEN(scenario.fen, gameType: mod);
          final orchestrator = Orchestrator();
          final legalMoves = orchestrator.getAllValidMoves(board);
          final hasCastling = legalMoves.any(_isCastlingMove);
          final hasQuietKingMove = legalMoves.any(_isQuietNonCastlingKingMove);
          final hasNonKingMove = legalMoves.any(
            (move) => move.piece.type.name != 'king',
          );
          final side = board.currentPlayer;
          final hadCastlingRights = _hasCastlingRights(board, side);

          expect(hasCastling, isTrue);
          expect(hasQuietKingMove, isTrue);
          expect(hasNonKingMove, isTrue);
          expect(hadCastlingRights, isTrue);

          final engine = NativeEngine();
          engine.resetState(clearTranspositionTable: true);
          final result = engine.findBestMoveSync(
            board,
            timeLimitMs: 1200,
            maxDepth: 7,
            skillLevel: 6,
          );

          final bestMove = result.bestMove;
          expect(bestMove, isNotNull);
          if (_isQuietNonCastlingKingMove(bestMove!)) {
            final nextBoard = orchestrator.executeMove(board, bestMove);
            final stillHasCastlingRights = _hasCastlingRights(nextBoard, side);
            expect(
              stillHasCastlingRights,
              isTrue,
              reason:
                  'Voluntary king move forfeited castling rights in ${mod.name} for ${scenario.name}',
            );
          }
          expect(
            _isQuietNonCastlingKingMove(bestMove),
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

bool _hasCastlingRights(ChessBoard board, PieceColor side) {
  if (side == PieceColor.white) {
    return board.whiteCanCastleKingside || board.whiteCanCastleQueenside;
  }
  return board.blackCanCastleKingside || board.blackCanCastleQueenside;
}

String _moveNotation(ChessMove move) {
  return '${move.from.algebraic}${move.to.algebraic}';
}
