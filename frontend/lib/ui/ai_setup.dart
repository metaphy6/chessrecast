import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../analytics/ai/ai_manager.dart';
import '../analytics/ai/ai_player.dart';
import '../board/items/piece_color.dart';
import '../modes/modes_enum.dart';
import '../routes.dart';

/// AI Setup Screen - Configure AI vs AI or Human vs AI games
/// Supports custom board setup via FEN
class AISetupScreen extends StatelessWidget {
  const AISetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final initialMode = args?['gameType'] ?? ModesEnum.mercenary;
    final customFEN = args?['customFEN'] as String?;

    final controller = Get.put(
      _AISetupController(initialMode, customFEN: customFEN),
      tag: 'ai_setup',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('AI Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title with AI badge
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.psychology, size: 32, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  '🧠 AI Configuration',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Neural Network AI (1800 ELO)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Game Type Selector
            _GameTypeSelector(controller: controller),
            const SizedBox(height: 16),

            // White Player Selection
            _PlayerSelector(
              title: 'White Player',
              controller: controller,
              isWhite: true,
            ),
            const SizedBox(height: 16),

            // Black Player Selection
            _PlayerSelector(
              title: 'Black Player',
              controller: controller,
              isWhite: false,
            ),
            const SizedBox(height: 16),

            // Game Mode Selection
            _GameModeSelector(controller: controller),
            const SizedBox(height: 16),

            // Custom Board Info (if applicable)
            if (customFEN != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Custom Board Position',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Starting from custom FEN:\n$customFEN',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Auto-play Settings (for AI vs AI)
            _PlaybackSettings(controller: controller),
            const SizedBox(height: 24),

            // Start Button
            ElevatedButton.icon(
              onPressed: () => controller.startAIGame(),
              icon: const Icon(Icons.play_arrow, size: 32),
              label: GetBuilder<_AISetupController>(
                id: 'game_type',
                tag: 'ai_setup',
                builder: (c) => Text(
                  c.isAIvsAI ? 'Start AI Battle' : 'Start Game vs AI',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About AI Players',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Neural network trained on Mercenary mode\n'
                    '• Strength: ~1800 ELO (intermediate player)\n'
                    '• Uses deep learning for move selection\n'
                    '• Different from rule-based bots',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controller for AI setup
class _AISetupController extends GetxController {
  PlayerType whitePlayer = PlayerType.ai;
  PlayerType blackPlayer = PlayerType.human;
  AIPlayerType aiType = AIPlayerType.mercenary1800;
  ModesEnum selectedMode;
  int moveDelay = 1500;
  bool autoPlay = true;
  String? customFEN;

  _AISetupController(this.selectedMode, {this.customFEN});

  bool get isAIvsAI =>
      whitePlayer == PlayerType.ai && blackPlayer == PlayerType.ai;
  bool get hasHuman =>
      whitePlayer == PlayerType.human || blackPlayer == PlayerType.human;

  void setWhitePlayer(PlayerType type) {
    whitePlayer = type;
    update(['white_player', 'game_type']);
  }

  void setBlackPlayer(PlayerType type) {
    blackPlayer = type;
    update(['black_player', 'game_type']);
  }

  void setGameMode(ModesEnum mode) {
    selectedMode = mode;
    update(['game_mode']);
  }

  void setAutoPlay(bool value) {
    autoPlay = value;
    update(['auto_play']);
  }

  void setMoveDelay(int delay) {
    moveDelay = delay;
    update(['move_delay']);
  }

  void startAIGame() async {
    final aiManager = Get.find<AIManager>();

    // Ensure AI is initialized
    if (!aiManager.isInitialized.value) {
      Get.dialog(
        const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing AI...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      try {
        await aiManager.initialize();
        Get.back(); // Close loading dialog
      } catch (e) {
        Get.back();
        Get.snackbar(
          'Error',
          'Failed to initialize AI: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
    }

    // Configure AI manager
    aiManager.moveDelay.value = moveDelay;

    if (isAIvsAI) {
      await aiManager.setupAIVsAI(
        whiteType: aiType,
        blackType: aiType,
        gameMode: selectedMode,
      );

      if (autoPlay) {
        aiManager.startAutoPlay();
      }
    } else {
      final humanColor = whitePlayer == PlayerType.human
          ? PieceColor.white
          : PieceColor.black;

      await aiManager.setupHumanVsAI(
        humanColor: humanColor,
        aiType: aiType,
        gameMode: selectedMode,
      );
    }

    // Navigate to chess game
    Get.toNamed(
      AppRoutes.chess,
      arguments: {
        'gameType': selectedMode,
        'isDevBoard': false,
        'isAIGame': true,
        if (customFEN != null) 'customFEN': customFEN,
      },
    );
  }
}

enum PlayerType {
  human,
  ai;

  String get displayName {
    switch (this) {
      case PlayerType.human:
        return 'Human';
      case PlayerType.ai:
        return 'AI (1800)';
    }
  }
}

/// Game Type Selector Widget
class _GameTypeSelector extends StatelessWidget {
  final _AISetupController controller;

  const _GameTypeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_AISetupController>(
      id: 'game_type',
      tag: 'ai_setup',
      builder: (c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _GameTypeButton(
              label: '🧠 AI vs AI',
              isSelected: c.isAIvsAI,
              onTap: () {
                c.setWhitePlayer(PlayerType.ai);
                c.setBlackPlayer(PlayerType.ai);
              },
            ),
            _GameTypeButton(
              label: '🎮 Human vs AI',
              isSelected: c.hasHuman,
              onTap: () {
                c.setWhitePlayer(PlayerType.human);
                c.setBlackPlayer(PlayerType.ai);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GameTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Player Selector Widget
class _PlayerSelector extends StatelessWidget {
  final String title;
  final _AISetupController controller;
  final bool isWhite;

  const _PlayerSelector({
    required this.title,
    required this.controller,
    required this.isWhite,
  });

  @override
  Widget build(BuildContext context) {
    final id = isWhite ? 'white_player' : 'black_player';

    return GetBuilder<_AISetupController>(
      id: id,
      tag: 'ai_setup',
      builder: (c) {
        final currentPlayer = isWhite ? c.whitePlayer : c.blackPlayer;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<PlayerType>(
                value: currentPlayer,
                isExpanded: true,
                items: PlayerType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (type) {
                  if (type != null) {
                    if (isWhite) {
                      c.setWhitePlayer(type);
                    } else {
                      c.setBlackPlayer(type);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Game Mode Selector (reused from bot_setup)
class _GameModeSelector extends StatelessWidget {
  final _AISetupController controller;

  const _GameModeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_AISetupController>(
      id: 'game_mode',
      tag: 'ai_setup',
      builder: (c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Game Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<ModesEnum>(
              value: c.selectedMode,
              isExpanded: true,
              items: ModesEnum.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode.displayName),
                );
              }).toList(),
              onChanged: (mode) {
                if (mode != null) {
                  c.setGameMode(mode);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Playback Settings Widget
class _PlaybackSettings extends StatelessWidget {
  final _AISetupController controller;

  const _PlaybackSettings({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<_AISetupController>(
      id: 'game_type',
      tag: 'ai_setup',
      builder: (c) {
        if (!c.isAIvsAI) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto-Play Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GetBuilder<_AISetupController>(
                id: 'auto_play',
                tag: 'ai_setup',
                builder: (c) => SwitchListTile(
                  title: const Text('Auto-play moves'),
                  value: c.autoPlay,
                  onChanged: c.setAutoPlay,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              GetBuilder<_AISetupController>(
                id: 'move_delay',
                tag: 'ai_setup',
                builder: (c) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Move delay: ${c.moveDelay}ms'),
                    Slider(
                      value: c.moveDelay.toDouble(),
                      min: 500,
                      max: 3000,
                      divisions: 10,
                      onChanged: (value) => c.setMoveDelay(value.toInt()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
