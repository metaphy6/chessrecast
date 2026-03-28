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
  Position? whiteQueenPos;
  Position? blackQueenPos;

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
          whiteQueenPos = p.position;
        } else {
          blackQueens++;
          blackQueenPos = p.position;
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
        isMerc,
      );
    }
    if (blackKingPos != null) {
      blackScore += _kingShield(
        pawnGrid,
        blackKingPos,
        PieceColor.black,
        mgWeight,
        isMerc,
      );
    }
  }

  // ── Mod-specific bonuses ──
  if (isMerc) {
    // In Mercenary, pawns are very strong (king-like movement). Value them more.
    whiteScore += whitePawns * 30;
    blackScore += blackPawns * 30;

    // Heavy and minor pieces that sit next to enemy pawns are far less stable
    // in Mercenary because those pawns move and capture like kings.
    whiteScore -= _evaluateMercenaryPieceExposure(board, PieceColor.white);
    blackScore -= _evaluateMercenaryPieceExposure(board, PieceColor.black);

    whiteScore += _evaluateMercenaryConversion(
      board,
      PieceColor.white,
      whiteKingPos,
      whiteQueenPos,
      blackKingPos,
      egWeight,
    );
    blackScore += _evaluateMercenaryConversion(
      board,
      PieceColor.black,
      blackKingPos,
      blackQueenPos,
      whiteKingPos,
      egWeight,
    );
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
  bool isMerc,
) {
  final pawnCode = color == PieceColor.white ? 1 : 2;

  if (isMerc) {
    var shield = 0;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final row = kingPos.row + dr;
        final col = kingPos.col + dc;
        if (row < 0 || row > 7 || col < 0 || col > 7) continue;
        if (pawnGrid[row][col] == pawnCode) {
          shield += 13;
        }
      }
    }
    final weight = mgWeight > 140 ? mgWeight : 140;
    return (shield * weight) ~/ 256;
  }

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

int _evaluateMercenaryPieceExposure(ChessBoard board, PieceColor color) {
  final enemyPawns = board.pieces.where(
    (piece) => piece.color != color && piece.type == PieceType.pawn,
  );
  var penalty = 0;

  for (final piece in board.pieces) {
    if (piece.color != color) continue;
    if (piece.type == PieceType.pawn || piece.type == PieceType.king) continue;

    final isExposed = enemyPawns.any((enemyPawn) {
      final rowDelta = (enemyPawn.position.row - piece.position.row).abs();
      final colDelta = (enemyPawn.position.col - piece.position.col).abs();
      return rowDelta <= 1 && colDelta <= 1;
    });

    if (!isExposed) continue;

    switch (piece.type) {
      case PieceType.knight:
      case PieceType.bishop:
        penalty += 35;
        break;
      case PieceType.rook:
        penalty += 60;
        break;
      case PieceType.queen:
        penalty += 110;
        break;
      case PieceType.pawn:
      case PieceType.king:
        break;
    }
  }

  return penalty;
}

int _evaluateMercenaryConversion(
  ChessBoard board,
  PieceColor color,
  Position? ownKingPos,
  Position? ownQueenPos,
  Position? enemyKingPos,
  int egWeight,
) {
  if (ownKingPos == null || enemyKingPos == null || egWeight < 80) {
    return 0;
  }

  var ownMaterial = 0;
  var enemyMaterial = 0;
  var enemyNonPawnMaterial = 0;

  for (final piece in board.pieces) {
    final value = _mercenaryMaterialValue(piece.type);
    if (piece.color == color) {
      ownMaterial += value;
    } else {
      enemyMaterial += value;
      if (piece.type != PieceType.pawn && piece.type != PieceType.king) {
        enemyNonPawnMaterial += value;
      }
    }
  }

  final lead = ownMaterial - enemyMaterial;
  var bonus = _evaluateMercenaryKingRoute(
    ownKingPos,
    enemyKingPos,
    egWeight,
    lead,
  );
  if (ownQueenPos != null) {
    bonus += _evaluateMercenaryQueenInfiltration(
      ownQueenPos,
      enemyKingPos,
      egWeight,
      lead,
    );
  }

  if (lead <= 0) return bonus;

  final cappedLead = lead > 700 ? 700 : lead;
  final simplifyBudget = 2200 - enemyNonPawnMaterial;
  final simplifyPressure =
      ((simplifyBudget > 0 ? simplifyBudget : 0) * cappedLead * egWeight) ~/
      1638400;
  final kingDistance = _chebyshevDistance(ownKingPos, enemyKingPos);
  final kingApproach = ((8 - kingDistance) * cappedLead * egWeight) ~/ 30720;
  final kingDrive =
      (_distanceFromCenter(enemyKingPos) * cappedLead * egWeight) ~/ 51200;

  return bonus + simplifyPressure + kingApproach + kingDrive;
}

int _evaluateMercenaryKingRoute(
  Position ownKingPos,
  Position enemyKingPos,
  int egWeight,
  int lead,
) {
  final fileGap = (ownKingPos.col - enemyKingPos.col).abs();
  final fileAlignment = (4 - fileGap).clamp(0, 4);
  final kingCenter = (6 - _distanceFromCenter(ownKingPos)).clamp(0, 6);
  final pressure = lead <= 0 ? 0 : (lead > 700 ? 700 : lead);

  return fileAlignment * (10 + egWeight ~/ 6) +
      kingCenter * (4 + egWeight ~/ 24) +
      (fileAlignment * pressure) ~/ 80;
}

int _evaluateMercenaryQueenInfiltration(
  Position ownQueenPos,
  Position enemyKingPos,
  int egWeight,
  int lead,
) {
  final queenDistance = _chebyshevDistance(ownQueenPos, enemyKingPos);
  final queenApproach = (7 - queenDistance).clamp(0, 7);
  final fileGap = (ownQueenPos.col - enemyKingPos.col).abs();
  final rankGap = (ownQueenPos.row - enemyKingPos.row).abs();
  final lanePressure =
      (fileGap <= 2 ? 3 - fileGap : 0) + (rankGap <= 2 ? 3 - rankGap : 0);
  final pressure = lead <= 0 ? 0 : (lead > 700 ? 700 : lead);

  return queenApproach * (8 + egWeight ~/ 16) +
      lanePressure * (10 + egWeight ~/ 24) +
      (queenApproach * pressure) ~/ 60;
}

int _mercenaryMaterialValue(PieceType type) {
  switch (type) {
    case PieceType.pawn:
      return 180;
    case PieceType.knight:
      return 320;
    case PieceType.bishop:
      return 330;
    case PieceType.rook:
      return 500;
    case PieceType.queen:
      return 900;
    case PieceType.king:
      return 0;
  }
}

int _chebyshevDistance(Position a, Position b) {
  final rowDistance = (a.row - b.row).abs();
  final colDistance = (a.col - b.col).abs();
  return rowDistance > colDistance ? rowDistance : colDistance;
}

int _distanceFromCenter(Position position) {
  final rowDistance = position.row < 4 ? 3 - position.row : position.row - 4;
  final colDistance = position.col < 4 ? 3 - position.col : position.col - 4;
  return rowDistance + colDistance;
}
