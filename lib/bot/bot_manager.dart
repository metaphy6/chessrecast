import 'package:get/get.dart';
import '../board/types/piece_color.dart';
import '../modes/modes_enum.dart';
import '../debug.dart';
import 'chess_bot.dart';
import 'random_bot.dart';
import 'greedy_bot.dart';
import 'isolate_bot.dart';

/// Manages bot players and bot vs bot games
class BotManager extends GetxController {
  ChessBot? _whiteBot;
  ChessBot? _blackBot;

  final RxBool isBotGame = false.obs;
  final RxBool isAutoPlaying = false.obs;
  final RxBool isPaused = false.obs;
  final RxInt moveDelay = 1000.obs; // ms between moves in auto-play

  ChessBot? get whiteBot => _whiteBot;
  ChessBot? get blackBot => _blackBot;

  /// Check if it's a bot's turn
  bool isBotTurn(PieceColor currentPlayer) {
    if (!isBotGame.value) return false;
    return (currentPlayer == PieceColor.white && _whiteBot != null) ||
        (currentPlayer == PieceColor.black && _blackBot != null);
  }

  /// Get the bot for the current player
  ChessBot? getBotForPlayer(PieceColor player) {
    return player == PieceColor.white ? _whiteBot : _blackBot;
  }

  /// Setup a bot vs bot game
  void setupBotVsBot({
    required BotType whiteType,
    required BotType blackType,
    required ModesEnum gameMode,
  }) {
    _whiteBot = _createBot(whiteType, PieceColor.white, 'White Bot');
    _blackBot = _createBot(blackType, PieceColor.black, 'Black Bot');
    isBotGame.value = true;

    logBot(
      'Manager',
      'Bot vs Bot game set up: ${whiteType.name} (White) vs ${blackType.name} (Black)',
    );
    logBot('Manager', 'Game mode: ${gameMode.displayName}');
  }

  /// Setup a human vs bot game
  void setupHumanVsBot({
    required PieceColor humanColor,
    required BotType botType,
    required ModesEnum gameMode,
  }) {
    final botColor = humanColor == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;

    if (botColor == PieceColor.white) {
      _whiteBot = _createBot(botType, botColor, 'Bot');
      _blackBot = null;
    } else {
      _whiteBot = null;
      _blackBot = _createBot(botType, botColor, 'Bot');
    }

    isBotGame.value = true;

    logBot('Manager', 'Human vs Bot game set up');
    logBot(
      'Manager',
      'Human: ${humanColor.name}, Bot: ${botType.name} (${botColor.name})',
    );
    logBot('Manager', 'Game mode: ${gameMode.displayName}');
  }

  /// Start auto-playing (for bot vs bot)
  void startAutoPlay() {
    if (_whiteBot != null && _blackBot != null) {
      isAutoPlaying.value = true;
      isPaused.value = false;
      logBot('Manager', 'Auto-play started');
    }
  }

  /// Pause auto-play
  void pauseAutoPlay() {
    isPaused.value = true;
    logBot('Manager', 'Auto-play paused');
  }

  /// Resume auto-play
  void resumeAutoPlay() {
    isPaused.value = false;
    logBot('Manager', 'Auto-play resumed');
  }

  /// Stop auto-play
  void stopAutoPlay() {
    isAutoPlaying.value = false;
    isPaused.value = false;
    logBot('Manager', 'Auto-play stopped');
  }

  /// Clear all bots and reset
  void clear() {
    _whiteBot = null;
    _blackBot = null;
    isBotGame.value = false;
    isAutoPlaying.value = false;
    isPaused.value = false;
    logBot('Manager', 'Bots cleared');
  }

  /// Create a bot based on type
  ChessBot _createBot(BotType type, PieceColor color, String name) {
    switch (type) {
      case BotType.random:
        return RandomBot(name: name, color: color, thinkingDelayMs: 300);
      case BotType.greedy:
        return GreedyBot(name: name, color: color, thinkingDelayMs: 100);
      case BotType.isolate:
        return IsolateBot(name: name, color: color, thinkingDelayMs: 100);
    }
  }
}

/// Available bot types
enum BotType {
  random,
  greedy,
  isolate;

  String get displayName {
    switch (this) {
      case BotType.random:
        return 'Random Bot';
      case BotType.greedy:
        return 'Greedy Bot';
      case BotType.isolate:
        return 'Fast Bot';
    }
  }

  String get description {
    switch (this) {
      case BotType.random:
        return 'Picks random moves';
      case BotType.greedy:
        return 'Prioritizes captures';
      case BotType.isolate:
        return 'Quick random moves';
    }
  }
}
