import '../board/board.dart';
import '../board/pieces/piece_color.dart';
import '../board/pieces/piece_type.dart';
import '../board/moves/position.dart';
import '../board/game_status.dart';
import '../mods/mods_enum.dart';

// ─── Position Evaluation ─────────────────────────────────────────────────────
//
// Evaluates a chess position from the perspective of the side to move.
// Positive = good for side-to-move, negative = good for opponent.
// All values are in centipawns (100 = 1 pawn).
//
// Features:
//  • Material count (piece values)
//  • Piece-Square Tables (PST) — positional bonuses per piece per square
//  • Mobility — number of pseudo-legal destinations
//  • King safety — pawn shield, open files near king
//  • Pawn structure — doubled, isolated, passed pawns
//  • Mod-specific adjustments (Mercenary, Succession, etc.)

const int infinity = 999999;
const int mateScore = 100000;

/// Return true if [score] represents a forced mate.
bool isMateScore(int score) => score.abs() > mateScore - 500;

/// Material values in centipawns.
const Map<PieceType, int> pieceValue = {
  PieceType.pawn: 100,
  PieceType.knight: 320,
  PieceType.bishop: 330,
  PieceType.rook: 500,
  PieceType.queen: 900,
  PieceType.king: 0, // King has no material value
};

// ── Piece-Square Tables ──────────────────────────────────────────────────────
// Indexed [row 0-7][col 0-7].  Row 0 = rank 1 (white's back rank).
// Values are from white's perspective; negate for black.

const _pawnPST = [
  [0, 0, 0, 0, 0, 0, 0, 0],
  [5, 10, 10, -20, -20, 10, 10, 5],
  [5, -5, -10, 0, 0, -10, -5, 5],
  [0, 0, 0, 20, 20, 0, 0, 0],
  [5, 5, 10, 25, 25, 10, 5, 5],
  [10, 10, 20, 30, 30, 20, 10, 10],
  [50, 50, 50, 50, 50, 50, 50, 50],
  [0, 0, 0, 0, 0, 0, 0, 0],
];

const _knightPST = [
  [-50, -40, -30, -30, -30, -30, -40, -50],
  [-40, -20, 0, 5, 5, 0, -20, -40],
  [-30, 5, 10, 15, 15, 10, 5, -30],
  [-30, 0, 15, 20, 20, 15, 0, -30],
  [-30, 5, 15, 20, 20, 15, 5, -30],
  [-30, 0, 10, 15, 15, 10, 0, -30],
  [-40, -20, 0, 0, 0, 0, -20, -40],
  [-50, -40, -30, -30, -30, -30, -40, -50],
];

const _bishopPST = [
  [-20, -10, -10, -10, -10, -10, -10, -20],
  [-10, 5, 0, 0, 0, 0, 5, -10],
  [-10, 10, 10, 10, 10, 10, 10, -10],
  [-10, 0, 10, 10, 10, 10, 0, -10],
  [-10, 5, 5, 10, 10, 5, 5, -10],
  [-10, 0, 5, 10, 10, 5, 0, -10],
  [-10, 0, 0, 0, 0, 0, 0, -10],
  [-20, -10, -10, -10, -10, -10, -10, -20],
];

const _rookPST = [
  [0, 0, 0, 5, 5, 0, 0, 0],
  [-5, 0, 0, 0, 0, 0, 0, -5],
  [-5, 0, 0, 0, 0, 0, 0, -5],
  [-5, 0, 0, 0, 0, 0, 0, -5],
  [-5, 0, 0, 0, 0, 0, 0, -5],
  [-5, 0, 0, 0, 0, 0, 0, -5],
  [5, 10, 10, 10, 10, 10, 10, 5],
  [0, 0, 0, 0, 0, 0, 0, 0],
];

const _queenPST = [
  [-20, -10, -10, -5, -5, -10, -10, -20],
  [-10, 0, 5, 0, 0, 0, 0, -10],
  [-10, 5, 5, 5, 5, 5, 0, -10],
  [0, 0, 5, 5, 5, 5, 0, -5],
  [-5, 0, 5, 5, 5, 5, 0, -5],
  [-10, 0, 5, 5, 5, 5, 0, -10],
  [-10, 0, 0, 0, 0, 0, 0, -10],
  [-20, -10, -10, -5, -5, -10, -10, -20],
];

const _kingMiddlePST = [
  [20, 30, 10, 0, 0, 10, 30, 20],
  [20, 20, 0, 0, 0, 0, 20, 20],
  [-10, -20, -20, -20, -20, -20, -20, -10],
  [-20, -30, -30, -40, -40, -30, -30, -20],
  [-30, -40, -40, -50, -50, -40, -40, -30],
  [-30, -40, -40, -50, -50, -40, -40, -30],
  [-30, -40, -40, -50, -50, -40, -40, -30],
  [-30, -40, -40, -50, -50, -40, -40, -30],
];

const _kingEndgamePST = [
  [-50, -30, -30, -30, -30, -30, -30, -50],
  [-30, -30, 0, 0, 0, 0, -30, -30],
  [-30, -10, 20, 30, 30, 20, -10, -30],
  [-30, -10, 30, 40, 40, 30, -10, -30],
  [-30, -10, 30, 40, 40, 30, -10, -30],
  [-30, -10, 20, 30, 30, 20, -10, -30],
  [-30, -20, -10, 0, 0, -10, -20, -30],
  [-50, -40, -30, -20, -20, -30, -40, -50],
];

/// Mercenary pawns (king-like movement) — centrality is key
const _mercenaryPawnPST = [
  [0, 0, 0, 0, 0, 0, 0, 0],
  [5, 5, 5, 5, 5, 5, 5, 5],
  [5, 10, 15, 20, 20, 15, 10, 5],
  [10, 15, 25, 30, 30, 25, 15, 10],
  [10, 15, 25, 30, 30, 25, 15, 10],
  [5, 10, 15, 20, 20, 15, 10, 5],
  [5, 5, 5, 5, 5, 5, 5, 5],
  [0, 0, 0, 0, 0, 0, 0, 0],
];

// ─── Evaluation Function ─────────────────────────────────────────────────────

/// Evaluate the position from the perspective of the side to move.
int evaluate(ChessBoard board) {
  // Terminal positions
  if (board.gameStatus == GameStatus.checkmate) {
    return -mateScore; // Current side is mated
  }
  if (board.gameStatus == GameStatus.stalemate ||
      board.gameStatus == GameStatus.draw) {
    return 0;
  }

  final isMerc = board.gameType == ModsEnum.mercenary;
  final isSuccession = board.gameType == ModsEnum.succession;

  var whiteScore = 0;
  var blackScore = 0;

  // Total material for endgame detection
  var whiteMaterial = 0;
  var blackMaterial = 0;
  var whitePawns = 0;
  var blackPawns = 0;

  // Piece counts for bishop pair bonus
  var whiteBishops = 0;
  var blackBishops = 0;
  var whiteQueens = 0;
  var blackQueens = 0;

  // Build a fast 8×8 lookup for pawn structure analysis
  // 0 = empty, 1 = white pawn, 2 = black pawn
  final pawnGrid = List<List<int>>.generate(8, (_) => List<int>.filled(8, 0));

  Position? whiteKingPos;
  Position? blackKingPos;

  for (final p in board.pieces) {
    final row = p.position.row;
    final col = p.position.col;
    final val = pieceValue[p.type] ?? 0;
    final isWhite = p.color == PieceColor.white;

    // Material
    if (isWhite) {
      whiteMaterial += val;
    } else {
      blackMaterial += val;
    }

    // PST
    final pstRow = isWhite ? row : 7 - row;
    int pstBonus;

    switch (p.type) {
      case PieceType.pawn:
        pstBonus = isMerc
            ? _mercenaryPawnPST[pstRow][col]
            : _pawnPST[pstRow][col];
        if (isWhite) {
          whitePawns++;
          pawnGrid[row][col] = 1;
        } else {
          blackPawns++;
          pawnGrid[row][col] = 2;
        }
        break;
      case PieceType.knight:
        pstBonus = _knightPST[pstRow][col];
        break;
      case PieceType.bishop:
        pstBonus = _bishopPST[pstRow][col];
        if (isWhite) {
          whiteBishops++;
        } else {
          blackBishops++;
        }
        break;
      case PieceType.rook:
        pstBonus = _rookPST[pstRow][col];
        break;
      case PieceType.queen:
        pstBonus = _queenPST[pstRow][col];
        if (isWhite) {
          whiteQueens++;
        } else {
          blackQueens++;
        }
        break;
      case PieceType.king:
        if (isWhite) {
          whiteKingPos = p.position;
        } else {
          blackKingPos = p.position;
        }
        // King PST depends on game phase — defer to below
        pstBonus = 0;
        break;
    }

    if (isWhite) {
      whiteScore += val + pstBonus;
    } else {
      blackScore += val + pstBonus;
    }
  }

  // ── Game Phase (0 = endgame, 256 = middlegame) ──
  final totalMat = whiteMaterial + blackMaterial;
  // Opening material ≈ 2*(Q+2R+2B+2N+8P) = 2*(900+1000+660+640+800) = 8000
  final phase = (totalMat * 256) ~/ 8000;
  final mgWeight = phase.clamp(0, 256);
  final egWeight = 256 - mgWeight;

  // King PST interpolated between middle-game and endgame
  if (whiteKingPos != null) {
    final r = whiteKingPos.row;
    final c = whiteKingPos.col;
    final mg = _kingMiddlePST[r][c];
    final eg = _kingEndgamePST[r][c];
    whiteScore += (mg * mgWeight + eg * egWeight) ~/ 256;
  }
  if (blackKingPos != null) {
    final r = 7 - blackKingPos.row;
    final c = blackKingPos.col;
    final mg = _kingMiddlePST[r][c];
    final eg = _kingEndgamePST[r][c];
    blackScore += (mg * mgWeight + eg * egWeight) ~/ 256;
  }

  // ── Bishop Pair Bonus ──
  if (whiteBishops >= 2) whiteScore += 30;
  if (blackBishops >= 2) blackScore += 30;

  // ── Pawn Structure ──
  whiteScore += _evaluatePawnStructure(pawnGrid, PieceColor.white, isMerc);
  blackScore += _evaluatePawnStructure(pawnGrid, PieceColor.black, isMerc);

  // ── King Safety (pawn shield) — middlegame only ──
  if (mgWeight > 64) {
    if (whiteKingPos != null) {
      whiteScore += _kingShield(
        pawnGrid,
        whiteKingPos,
        PieceColor.white,
        mgWeight,
      );
    }
    if (blackKingPos != null) {
      blackScore += _kingShield(
        pawnGrid,
        blackKingPos,
        PieceColor.black,
        mgWeight,
      );
    }
  }

  // ── Mod-specific bonuses ──
  if (isMerc) {
    // In Mercenary, pawns are very strong (king-like movement). Value them more.
    whiteScore += whitePawns * 30;
    blackScore += blackPawns * 30;
  }

  if (isSuccession) {
    // In Succession, pawns are critical (must promote to king to win).
    // Queens are also critical (losing a queen = instant loss).
    whiteScore += whitePawns * 40;
    blackScore += blackPawns * 40;
    whiteScore += whiteQueens * 200; // Extra incentive to protect queens
    blackScore += blackQueens * 200;
  }

  // ── Final Score (relative to side to move) ──
  final rawScore = whiteScore - blackScore;
  return board.currentPlayer == PieceColor.white ? rawScore : -rawScore;
}

// ─── Pawn Structure ──────────────────────────────────────────────────────────

int _evaluatePawnStructure(
  List<List<int>> pawnGrid,
  PieceColor color,
  bool isMerc,
) {
  final pawnCode = color == PieceColor.white ? 1 : 2;
  final enemyCode = color == PieceColor.white ? 2 : 1;
  final direction = color == PieceColor.white ? 1 : -1;
  var bonus = 0;

  for (var row = 0; row < 8; row++) {
    for (var col = 0; col < 8; col++) {
      if (pawnGrid[row][col] != pawnCode) continue;

      // Doubled pawns (another pawn of same color on same file)
      var doubled = false;
      for (var r = 0; r < 8; r++) {
        if (r != row && pawnGrid[r][col] == pawnCode) {
          doubled = true;
          break;
        }
      }
      if (doubled) bonus -= 15;

      // Isolated pawn (no friendly pawns on adjacent files)
      var isolated = true;
      for (var r = 0; r < 8; r++) {
        if (col > 0 && pawnGrid[r][col - 1] == pawnCode) {
          isolated = false;
          break;
        }
        if (col < 7 && pawnGrid[r][col + 1] == pawnCode) {
          isolated = false;
          break;
        }
      }
      if (isolated) bonus -= 20;

      // Passed pawn (no enemy pawns on same or adjacent files ahead)
      if (!isMerc) {
        // In Mercenary, pawns don't promote — passed pawns are less relevant
        var passed = true;
        final startR = row + direction;
        final endR = color == PieceColor.white ? 8 : -1;
        for (var r = startR; r != endR; r += direction) {
          if (r < 0 || r > 7) break;
          for (var dc = -1; dc <= 1; dc++) {
            final c = col + dc;
            if (c >= 0 && c < 7 && pawnGrid[r][c] == enemyCode) {
              passed = false;
              break;
            }
          }
          if (!passed) break;
        }
        if (passed) {
          // Passed pawn bonus increases as it advances
          final advancement = color == PieceColor.white ? row : 7 - row;
          bonus += 10 + advancement * advancement * 3;
        }
      }
    }
  }

  return bonus;
}

// ─── King Safety ─────────────────────────────────────────────────────────────

int _kingShield(
  List<List<int>> pawnGrid,
  Position kingPos,
  PieceColor color,
  int mgWeight,
) {
  final pawnCode = color == PieceColor.white ? 1 : 2;
  final shieldRow = color == PieceColor.white
      ? kingPos.row + 1
      : kingPos.row - 1;

  if (shieldRow < 0 || shieldRow > 7) return 0;

  var shield = 0;
  for (var dc = -1; dc <= 1; dc++) {
    final c = kingPos.col + dc;
    if (c >= 0 && c < 8 && pawnGrid[shieldRow][c] == pawnCode) {
      shield += 10;
    }
  }

  // Scale by middlegame weight
  return (shield * mgWeight) ~/ 256;
}
