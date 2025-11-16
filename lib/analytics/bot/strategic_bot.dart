import 'dart:math';
import '../../board/entities/board.dart';
import '../../board/entities/move.dart';
import '../../board/types/piece_type.dart';
import '../../debug.dart';
import 'chess_bot.dart';
import 'evaluation/opening_book.dart';
import 'evaluation/position_cache.dart';
import 'evaluation/position_evaluator.dart';
import 'evaluation/tactical_patterns.dart';

/// Strategic bot with all improvements: opening book, tactics, position eval, caching
class StrategicBot extends ChessBot {
  final Random _random = Random();
  final int thinkingDelayMs;
  final PositionCache _cache = PositionCache();

  StrategicBot({
    required super.name,
    required super.color,
    this.thinkingDelayMs = 100,
  });

  @override
  String get description =>
      'Strategic player with opening book and tactical awareness';

  @override
  Future<ChessMove?> selectMove(
    ChessBoard board,
    List<ChessMove> validMoves,
  ) async {
    if (validMoves.isEmpty) {
      logBot(name, 'No valid moves available');
      return null;
    }

    // Phase 1: Check opening book first
    final bookMove = OpeningBook.getBookMove(board, validMoves);
    if (bookMove != null) {
      logBot(
        name,
        'Using opening book move: ${bookMove.from.algebraic}→${bookMove.to.algebraic}',
      );
      await Future.delayed(Duration(milliseconds: thinkingDelayMs));
      return bookMove;
    }

    // Phase 2: Evaluate all moves
    final scoredMoves = <(ChessMove, int)>[];

    for (final move in validMoves) {
      final score = _evaluateMove(board, move);
      scoredMoves.add((move, score));
    }

    // Sort moves by score (best first)
    scoredMoves.sort((a, b) => b.$2.compareTo(a.$2));

    // Get all moves with the best score (for variety)
    final bestScore = scoredMoves.first.$2;
    final bestMoves = scoredMoves
        .where((sm) => sm.$2 == bestScore)
        .map((sm) => sm.$1)
        .toList();

    // Pick randomly from best moves
    final selectedMove = bestMoves[_random.nextInt(bestMoves.length)];

    logBot(
      name,
      'Selected: ${selectedMove.from.algebraic}→${selectedMove.to.algebraic} '
      '(score: $bestScore)',
    );

    // Log cache stats periodically
    if (_random.nextInt(10) == 0) {
      final stats = _cache.getStats();
      logBot(name, 'Cache: ${stats['size']}/${stats['maxSize']} entries');
    }

    await Future.delayed(Duration(milliseconds: thinkingDelayMs));
    return selectedMove;
  }

  /// Evaluate a move comprehensively
  int _evaluateMove(ChessBoard board, ChessMove move) {
    // Start with base material and position value
    int score = _getBasicMoveValue(move);

    // Check cache for position evaluation after this move
    final boardAfterMove = _applyMove(board, move);
    final cachedScore = _cache.getEvaluation(boardAfterMove);

    if (cachedScore != null) {
      score += cachedScore;
    } else {
      // Evaluate resulting position
      final positionScore = PositionEvaluator.evaluatePosition(boardAfterMove);
      score += positionScore ~/ 10; // Scale down position eval

      // Cache the result
      _cache.storeEvaluation(boardAfterMove, positionScore);
    }

    // Tactical pattern bonuses
    if (TacticalPatterns.createsFork(move, board)) {
      score += 500;
      logBot(name, '  🍴 Fork detected at ${move.to.algebraic}!');
    }

    if (TacticalPatterns.createsDiscoveredAttack(move, board)) {
      score += 400;
      logBot(name, '  ⚡ Discovered attack with ${move.piece.type}!');
    }

    if (TacticalPatterns.removesPin(move, board)) {
      score += 300;
      logBot(name, '  🔓 Removes pin from ${move.from.algebraic}!');
    }

    if (TacticalPatterns.createsSkewer(move, board)) {
      score += 450;
      logBot(name, '  🎣 Skewer created!');
    }

    return score;
  }

  /// Get basic move value (captures, promotions, etc.)
  int _getBasicMoveValue(ChessMove move) {
    int score = 0;

    // Capture value
    if (move.capturedPiece != null) {
      score += _getPieceValue(move.capturedPiece!.type);

      // MVV-LVA: prefer capturing with less valuable pieces
      score -= _getPieceValue(move.piece.type) ~/ 10;
    }

    // Promotion bonus
    if (move.isPromotion) {
      score += 700;
    }

    // Castling bonus
    if (move.isCastling) {
      score += 50;
    }

    return score;
  }

  /// Apply move to board (simplified)
  ChessBoard _applyMove(ChessBoard board, ChessMove move) {
    final newPieces = board.pieces
        .where((p) => p.position != move.from && p.position != move.to)
        .toList();
    newPieces.add(move.piece.movedTo(move.to));

    return ChessBoard(
      pieces: newPieces,
      currentPlayer: board.currentPlayer.opposite,
      gameType: board.gameType,
      moveHistory: [...board.moveHistory, move],
    );
  }

  /// Get piece value
  int _getPieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 100;
      case PieceType.knight:
        return 320;
      case PieceType.bishop:
        return 330;
      case PieceType.rook:
        return 500;
      case PieceType.queen:
        return 900;
      case PieceType.king:
        return 20000;
    }
  }
}

