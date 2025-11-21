import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../analytics/bot/bot_manager.dart';
import '../modes/modes_enum.dart';
import '../routes.dart';

/// Bot setup screen with optimized state management to prevent jank
class BotSetupScreen extends StatelessWidget {
  const BotSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the game type from route arguments
    final args = Get.arguments as Map<String, dynamic>?;
    final initialMode = args?['gameType'] ?? ModesEnum.classic;

    // Create controller for this screen
    final controller = Get.put(
      _BotSetupController(initialMode),
      tag: 'bot_setup',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Bot vs Bot Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              '🤖 Bot Battle Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // White Bot Selection
            _BotSelector(
              title: 'White Bot',
              controller: controller,
              isWhite: true,
            ),
            const SizedBox(height: 16),

            // Black Bot Selection
            _BotSelector(
              title: 'Black Bot',
              controller: controller,
              isWhite: false,
            ),
            const SizedBox(height: 16),

            // Game Mode Selection
            _GameModeSelector(controller: controller),
            const SizedBox(height: 16),

            // Auto-play Settings
            _PlaybackSettings(controller: controller),
            const SizedBox(height: 24),

            // Start Button
            ElevatedButton.icon(
              onPressed: () => controller.startBotGame(),
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Text(
                'Start Bot Battle',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Controller for bot setup with GetX state management
class _BotSetupController extends GetxController {
  BotType whiteBot = BotType.greedy;
  BotType blackBot = BotType.random;
  ModesEnum selectedMode;
  int moveDelay = 1000;
  bool autoPlay = true;

  _BotSetupController(this.selectedMode);

  void setWhiteBot(BotType type) {
    whiteBot = type;
    update(['white_bot']);
  }

  void setBlackBot(BotType type) {
    blackBot = type;
    update(['black_bot']);
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

  void startBotGame() {
    final botManager = Get.find<BotManager>();

    // Configure bot manager
    botManager.setupBotVsBot(
      whiteType: whiteBot,
      blackType: blackBot,
      gameMode: selectedMode,
    );

    botManager.moveDelay.value = moveDelay;

    if (autoPlay) {
      botManager.startAutoPlay();
    }

    // Navigate to chess game
    Get.toNamed(
      AppRoutes.chess,
      arguments: {'gameType': selectedMode, 'isDevBoard': false},
    );
  }
}

/// Optimized bot selector widget
class _BotSelector extends StatelessWidget {
  final String title;
  final _BotSetupController controller;
  final bool isWhite;

  const _BotSelector({
    required this.title,
    required this.controller,
    required this.isWhite,
  });

  @override
  Widget build(BuildContext context) {
    final id = isWhite ? 'white_bot' : 'black_bot';

    // PERFORMANCE: Create dropdown items once, outside GetBuilder
    final dropdownItems = BotType.values.map((type) {
      return DropdownMenuItem(value: type, child: Text(type.displayName));
    }).toList();

    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              GetBuilder<_BotSetupController>(
                id: id,
                tag: 'bot_setup',
                builder: (_) {
                  final currentBot = isWhite
                      ? controller.whiteBot
                      : controller.blackBot;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<BotType>(
                        value: currentBot,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Bot Type',
                        ),
                        items: dropdownItems,
                        onChanged: (value) {
                          if (value != null) {
                            if (isWhite) {
                              controller.setWhiteBot(value);
                            } else {
                              controller.setBlackBot(value);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentBot.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optimized game mode selector
class _GameModeSelector extends StatelessWidget {
  final _BotSetupController controller;

  const _GameModeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: Create dropdown items once, outside GetBuilder
    final dropdownItems = ModesEnum.values.map((mode) {
      return DropdownMenuItem(value: mode, child: Text(mode.displayName));
    }).toList();

    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Game Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GetBuilder<_BotSetupController>(
                id: 'game_mode',
                tag: 'bot_setup',
                builder: (_) => DropdownButtonFormField<ModesEnum>(
                  value: controller.selectedMode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Select Mode',
                  ),
                  items: dropdownItems,
                  onChanged: (value) {
                    if (value != null) {
                      controller.setGameMode(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optimized playback settings
class _PlaybackSettings extends StatelessWidget {
  final _BotSetupController controller;

  const _PlaybackSettings({required this.controller});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Playback Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GetBuilder<_BotSetupController>(
                id: 'auto_play',
                tag: 'bot_setup',
                builder: (_) => SwitchListTile(
                  title: const Text('Auto-play'),
                  subtitle: const Text('Automatically play moves'),
                  value: controller.autoPlay,
                  onChanged: (value) => controller.setAutoPlay(value),
                ),
              ),
              const SizedBox(height: 8),
              GetBuilder<_BotSetupController>(
                id: 'move_delay',
                tag: 'bot_setup',
                builder: (_) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Move Delay: ${controller.moveDelay}ms'),
                    Slider(
                      value: controller.moveDelay.toDouble(),
                      min: 100,
                      max: 3000,
                      divisions: 29,
                      label: '${controller.moveDelay}ms',
                      onChanged: (value) =>
                          controller.setMoveDelay(value.toInt()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
