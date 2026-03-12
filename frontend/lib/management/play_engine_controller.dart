import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../board/pieces/piece_color.dart';
import '../engine/engine.dart';
import 'controller.dart';

/// Controller for the "Play vs Engine" mode.
///
/// Extends the normal game [Controller] so the board widget, info panels,
/// and undo/redo all work unchanged.  After each human move, the engine
/// automatically plays a reply.
class PlayEngineController extends Controller {
  final ChessEngine _engine = ChessEngine();

  /// Which colour the human plays.
  final Rx<PieceColor> humanColor = PieceColor.white.obs;

  /// Engine difficulty.
  final Rx<EngineLevel> engineLevel = EngineLevel.hard.obs;

  /// True while the engine is computing its move.
  final RxBool isThinking = false.obs;

  // Search stats for display
  final RxInt lastDepth = 0.obs;
  final RxInt lastScore = 0.obs;
  final RxInt lastNodes = 0.obs;
  final RxInt lastTimeMs = 0.obs;

  /// If the engine plays white, kick off its first move once the page loads.
  void startIfEngineFirst() {
    if (board.currentPlayer != humanColor.value && !isGameOver) {
      _playEngineMove();
    }
  }

  void setHumanColor(PieceColor color) {
    humanColor.value = color;
  }

  void setEngineLevel(EngineLevel level) {
    engineLevel.value = level;
  }

  /// Override: after a human square tap executes a move, check if the engine
  /// should respond.
  @override
  void onSquareSelected(position) {
    // Only allow interaction on the human's turn
    if (board.currentPlayer != humanColor.value || isThinking.value) return;
    super.onSquareSelected(position);

    // After the human move, if it's now the engine's turn and the game isn't
    // over, schedule the engine reply after a short delay (lets the UI update).
    if (!isGameOver && board.currentPlayer != humanColor.value) {
      Future.delayed(const Duration(milliseconds: 150), _playEngineMove);
    }
  }

  Future<void> _playEngineMove() async {
    if (isGameOver || isThinking.value) return;
    if (board.currentPlayer == humanColor.value) return;
    isThinking.value = true;

    try {
      final sw = Stopwatch()..start();
      final moveResult = await _engine.computeEngineMove(
        board,
        level: engineLevel.value,
      );
      sw.stop();

      if (isClosed) return;

      final result = moveResult.searchResult;
      lastDepth.value = result.depth;
      lastScore.value = result.score;
      lastNodes.value = result.nodesSearched;
      lastTimeMs.value = sw.elapsedMilliseconds;

      debugPrint(
        '[PlayEngine] depth=${result.depth} score=${result.score} '
        'nodes=${result.nodesSearched} time=${sw.elapsedMilliseconds}ms',
      );

      if (result.bestMove != null) {
        applyComputedMove(moveResult.newBoard);
      }
    } catch (e) {
      debugPrint('[PlayEngine] error: $e');
    }

    isThinking.value = false;
  }

  /// Undo the last engine move + the last human move (undo a full round).
  void undoRound() {
    if (isThinking.value) return;
    // Undo engine's move
    if (canUndo) undoLastMove();
    // Undo human's move
    if (canUndo) undoLastMove();
  }
}
