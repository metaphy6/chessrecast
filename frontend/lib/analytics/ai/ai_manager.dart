import 'package:get/get.dart';
import '../../board/pieces/piece_color.dart';
import '../../mods/mods_enum.dart';
import 'ai_player.dart';
import '../../services/ai_service.dart';

/// Manages AI players and AI games (AI vs AI, Human vs AI)
class AIManager extends GetxController {
  AIPlayer? _whiteAI;
  AIPlayer? _blackAI;

  final RxBool isAIGame = false.obs;
  final RxBool isAutoPlaying = false.obs;
  final RxBool isPaused = false.obs;
  final RxInt moveDelay =
      1500.obs; // ms between moves (AI needs more thinking time)
  final RxBool isInitialized = false.obs;

  AIPlayer? get whiteAI => _whiteAI;
  AIPlayer? get blackAI => _blackAI;

  /// Initialize AI service (call once at app start)
  Future<void> initialize() async {
    if (isInitialized.value) return;

    try {
      await AIService.instance.initialize();
      isInitialized.value = true;
      print('✓ AI Manager initialized');
    } catch (e) {
      print('❌ AI Manager initialization failed: $e');
      rethrow;
    }
  }

  /// Check if it's an AI's turn
  bool isAITurn(PieceColor currentPlayer) {
    if (!isAIGame.value) return false;
    return (currentPlayer == PieceColor.white && _whiteAI != null) ||
        (currentPlayer == PieceColor.black && _blackAI != null);
  }

  /// Get the AI for the current player
  AIPlayer? getAIForPlayer(PieceColor player) {
    return player == PieceColor.white ? _whiteAI : _blackAI;
  }

  /// Setup an AI vs AI game
  Future<void> setupAIVsAI({
    required AIPlayerType whiteType,
    required AIPlayerType blackType,
    required ModsEnum GameMod,
  }) async {
    await _ensureInitialized();

    _whiteAI = whiteType.createPlayer(
      PieceColor.white,
      thinkingDelayMs: moveDelay.value,
    );
    _blackAI = blackType.createPlayer(
      PieceColor.black,
      thinkingDelayMs: moveDelay.value,
    );

    isAIGame.value = true;
    print(
      '✓ AI vs AI game setup: ${whiteType.displayName} vs ${blackType.displayName}',
    );
  }

  /// Setup a Human vs AI game
  Future<void> setupHumanVsAI({
    required PieceColor humanColor,
    required AIPlayerType aiType,
    required ModsEnum GameMod,
  }) async {
    await _ensureInitialized();

    final aiColor = humanColor == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;

    if (aiColor == PieceColor.white) {
      _whiteAI = aiType.createPlayer(aiColor, thinkingDelayMs: moveDelay.value);
      _blackAI = null;
    } else {
      _whiteAI = null;
      _blackAI = aiType.createPlayer(aiColor, thinkingDelayMs: moveDelay.value);
    }

    isAIGame.value = true;
    print('✓ Human vs AI game setup: ${aiType.displayName} as ${aiColor.name}');
  }

  /// Start auto-playing (for AI vs AI)
  void startAutoPlay() {
    if (_whiteAI != null && _blackAI != null) {
      isAutoPlaying.value = true;
      isPaused.value = false;
      print('▶ AI auto-play started');
    }
  }

  /// Pause auto-play
  void pauseAutoPlay() {
    isPaused.value = true;
    update(['aiControls']);
  }

  /// Resume auto-play
  void resumeAutoPlay() {
    isPaused.value = false;
    update(['aiControls']);

    // Trigger next AI move
    Future.microtask(() {
      try {
        // Controller will check for AI turn
        Get.find<dynamic>().checkAITurn();
      } catch (_) {}
    });
  }

  /// Stop auto-play
  void stopAutoPlay() {
    isAutoPlaying.value = false;
    isPaused.value = false;
  }

  /// Clear all AIs and reset
  void clear() {
    _whiteAI = null;
    _blackAI = null;
    isAIGame.value = false;
    isAutoPlaying.value = false;
    isPaused.value = false;
  }

  /// Ensure AI service is initialized
  Future<void> _ensureInitialized() async {
    if (!isInitialized.value) {
      await initialize();
    }
  }

  @override
  void onClose() {
    clear();
    super.onClose();
  }
}
