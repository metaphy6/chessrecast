import 'dart:async';

import 'package:get/get.dart';
import '../board/moves/move.dart';
import '../board/pieces/piece_color.dart';
import '../board/game_status.dart';
import '../engine/engine.dart';
import '../management/controller.dart';

/// Controller for the "Watch Engine" screen.
///
/// Extends the normal game Controller so the board widget, info panels,
/// and undo/redo all work unchanged.  Adds an auto-play loop where the
/// engine plays both sides, plus live stats and playback controls.
class WatchEngineController extends Controller {
  final ChessEngine _engine = ChessEngine();

  // ── Reactive state for the UI ──────────────────────────────────────────
  final RxBool isPlaying = false.obs;
  final RxBool isPaused = false.obs;
  final RxInt moveDelayMs = 800.obs;
  final Rx<EngineLevel> whiteLevel = EngineLevel.hard.obs;
  final Rx<EngineLevel> blackLevel = EngineLevel.hard.obs;

  // Live search stats (updated after every move)
  final RxInt lastDepth = 0.obs;
  final RxInt lastScore = 0.obs;
  final RxInt lastNodes = 0.obs;
  final RxInt totalMoves = 0.obs;
  final RxInt whiteWins = 0.obs;
  final RxInt blackWins = 0.obs;
  final RxInt draws = 0.obs;
  final RxInt gamesPlayed = 0.obs;
  final RxBool autoRestart = true.obs;

  // Move log for the scroll panel
  final RxList<String> moveLog = <String>[].obs;

  Timer? _moveTimer;
  bool _thinking = false;

  @override
  void onInit() {
    super.onInit();
    // Start playing automatically
    Future.delayed(const Duration(milliseconds: 300), () => startPlaying());
  }

  @override
  void onClose() {
    _moveTimer?.cancel();
    super.onClose();
  }

  // ── Playback controls ──────────────────────────────────────────────────

  void startPlaying() {
    isPlaying.value = true;
    isPaused.value = false;
    _scheduleNextMove();
  }

  void pause() {
    isPaused.value = true;
    _moveTimer?.cancel();
  }

  void resume() {
    isPaused.value = false;
    _scheduleNextMove();
  }

  void togglePause() {
    if (isPaused.value) {
      resume();
    } else {
      pause();
    }
  }

  void stopPlaying() {
    isPlaying.value = false;
    isPaused.value = false;
    _moveTimer?.cancel();
  }

  void setMoveDelay(int ms) {
    moveDelayMs.value = ms;
  }

  void setWhiteLevel(EngineLevel level) {
    whiteLevel.value = level;
  }

  void setBlackLevel(EngineLevel level) {
    blackLevel.value = level;
  }

  /// Play one move manually (step-through mode).
  void stepOneMove() {
    if (!_thinking) {
      _playOneMove();
    }
  }

  /// Reset the board and continue auto-play.
  void restartGame() {
    resetGame();
    moveLog.clear();
    totalMoves.value = 0;
    if (isPlaying.value && !isPaused.value) {
      _scheduleNextMove();
    }
  }

  // ── Internal auto-play loop ────────────────────────────────────────────

  void _scheduleNextMove() {
    _moveTimer?.cancel();
    if (!isPlaying.value || isPaused.value) return;
    if (isGameOver) {
      _onGameOver();
      return;
    }
    _moveTimer = Timer(Duration(milliseconds: moveDelayMs.value), () {
      _playOneMove();
    });
  }

  Future<void> _playOneMove() async {
    if (_thinking || isGameOver) return;
    _thinking = true;

    try {
      final currentBoard = board;
      final level = currentBoard.currentPlayer == PieceColor.white
          ? whiteLevel.value
          : blackLevel.value;

      final result = _engine.findBestMoveSync(currentBoard, level: level);

      if (result.bestMove == null) {
        _thinking = false;
        _onGameOver();
        return;
      }

      // Update stats
      lastDepth.value = result.depth;
      lastScore.value = result.score;
      lastNodes.value = result.nodesSearched;
      totalMoves.value += 1;

      // Build move log entry
      final side = currentBoard.currentPlayer == PieceColor.white ? 'W' : 'B';
      final moveNum = (totalMoves.value + 1) ~/ 2;
      final scoreStr = _formatScore(result.score);
      moveLog.add(
        '$moveNum$side. ${_moveNotation(result.bestMove!)} '
        '(d${result.depth} $scoreStr ${_formatNodes(result.nodesSearched)})',
      );

      // Execute the move through the parent Controller's makeMove
      makeMove(result.bestMove!);
    } catch (e) {
      moveLog.add('⚠ Error: $e');
    }

    _thinking = false;

    // Schedule next
    if (!isGameOver) {
      _scheduleNextMove();
    } else {
      _onGameOver();
    }
  }

  void _onGameOver() {
    gamesPlayed.value += 1;
    final status = board.gameStatus;

    if (status == GameStatus.checkmate) {
      // The side that just moved won (current player is the loser)
      if (board.currentPlayer == PieceColor.black) {
        whiteWins.value += 1;
        moveLog.add('── White wins by checkmate ──');
      } else {
        blackWins.value += 1;
        moveLog.add('── Black wins by checkmate ──');
      }
    } else {
      draws.value += 1;
      final reason = status == GameStatus.stalemate ? 'stalemate' : 'draw';
      moveLog.add('── Draw ($reason) ──');
    }

    // Auto-restart after a short delay
    if (autoRestart.value && isPlaying.value) {
      Timer(const Duration(seconds: 2), () {
        if (isPlaying.value && !isPaused.value) {
          restartGame();
        }
      });
    }
  }

  // ── Formatting helpers ─────────────────────────────────────────────────

  String _formatScore(int score) {
    if (score.abs() > 90000) {
      final mateIn = (100000 - score.abs() + 1) ~/ 2;
      return score > 0 ? 'M$mateIn' : '-M$mateIn';
    }
    final cp = score / 100.0;
    return '${cp >= 0 ? '+' : ''}${cp.toStringAsFixed(1)}';
  }

  String _formatNodes(int nodes) {
    if (nodes >= 1000000) return '${(nodes / 1000000).toStringAsFixed(1)}Mn';
    if (nodes >= 1000) return '${(nodes / 1000).toStringAsFixed(1)}Kn';
    return '${nodes}n';
  }

  String _moveNotation(ChessMove move) {
    final piece = move.piece;
    const icons = {
      'pawn': '',
      'knight': 'N',
      'bishop': 'B',
      'rook': 'R',
      'queen': 'Q',
      'king': 'K',
    };
    final prefix = icons[piece.type.name] ?? '';
    final capture = move.isCapture ? 'x' : '';
    final promo = move.isPromotion ? '=${move.promotionPiece}' : '';
    return '$prefix${move.from.algebraic}$capture${move.to.algebraic}$promo';
  }
}
