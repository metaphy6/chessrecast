import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../analytics/bot/bot_manager.dart';
import '../management/controller.dart';
import '../management/online_controller.dart';
import '../ui/board_theme.dart';
import 'board.dart';
import 'info_panel.dart';

class ChessGamePage extends StatelessWidget {
  const ChessGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if we need online controller
    final args = Get.arguments as Map<String, dynamic>?;
    final isOnline = args?['isOnline'] ?? false;

    // Initialize the appropriate controller
    Controller controller;
    try {
      controller = Get.find<Controller>();
    } catch (e) {
      // Controller not found, create one
      if (isOnline) {
        controller = Get.put<Controller>(OnlineController());
      } else {
        controller = Get.put<Controller>(Controller());
      }
    }

    // Set the BuildContext for safe snackbar display
    controller.setBuildContext(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Flexible(
                  child: Text(
                    'Chess Recast',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (controller.isDevBoard) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEV',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              controller.gameType.displayName,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.brown.shade800,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => controller.navigateBack(),
          tooltip: controller.isDevBoard
              ? 'Back to Dev Board Setup'
              : 'Back to Game Selection',
        ),
        actions: [
          // Undo/Redo with GetBuilder instead of Obx for better performance
          GetBuilder<Controller>(
            id: 'history',
            builder: (controller) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white, size: 20),
                  onPressed: controller.canUndo
                      ? () => controller.undoLastMove()
                      : null,
                  tooltip: 'Undo',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.redo, color: Colors.white, size: 20),
                  onPressed: controller.canRedo
                      ? () => controller.redoMove()
                      : null,
                  tooltip: 'Redo',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Bot Controls (only show if bot game)
          GetBuilder<BotManager>(
            id: 'botControls',
            builder: (botManager) {
              if (!botManager.isBotGame.value) return const SizedBox.shrink();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pause/Resume button
                  if (botManager.isAutoPlaying.value)
                    IconButton(
                      icon: Icon(
                        botManager.isPaused.value
                            ? Icons.play_arrow
                            : Icons.pause,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        if (botManager.isPaused.value) {
                          botManager.resumeAutoPlay();
                        } else {
                          botManager.pauseAutoPlay();
                        }
                      },
                      tooltip: botManager.isPaused.value ? 'Resume' : 'Pause',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  // Speed control
                  PopupMenuButton<int>(
                    icon: const Icon(
                      Icons.speed,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Bot Speed',
                    padding: const EdgeInsets.all(8),
                    onSelected: (speed) {
                      botManager.moveDelay.value = speed;
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 100,
                        child: Text('Very Fast (0.1s)'),
                      ),
                      const PopupMenuItem(
                        value: 500,
                        child: Text('Fast (0.5s)'),
                      ),
                      const PopupMenuItem(
                        value: 1000,
                        child: Text('Normal (1s)'),
                      ),
                      const PopupMenuItem(
                        value: 2000,
                        child: Text('Slow (2s)'),
                      ),
                      const PopupMenuItem(
                        value: 3000,
                        child: Text('Very Slow (3s)'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          // Online Spectator Controls (pause/resume for bot vs bot)
          if (isOnline && controller is OnlineController)
            Obx(() {
              final onlineController = controller as OnlineController;
              if (!onlineController.isSpectator) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(
                  onlineController.isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => onlineController.togglePause(),
                tooltip: onlineController.isPaused ? 'Resume' : 'Pause',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              );
            }),
          // More menu with theme and reset
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            padding: const EdgeInsets.all(8),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'reset') {
                controller.resetGame();
              } else if (value == 'export') {
                // Export current position to custom board using FEN notation
                // FEN is a simple string - no serialization issues
                Get.offAllNamed(
                  '/custom-board',
                  arguments: {
                    'gameType': controller.gameType,
                    'fen': controller.board.toFEN(),
                  },
                );
              }
            },
            itemBuilder: (context) => [
              // Board theme submenu
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Board Theme',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...BoardTheme.values.map((theme) {
                      return GetBuilder<Controller>(
                        id: 'boardTheme',
                        builder: (controller) => InkWell(
                          onTap: () {
                            controller.setBoardTheme(theme);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  controller.boardTheme == theme
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(theme.displayName),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const Divider(),
                  ],
                ),
              ),
              // Reset button
              PopupMenuItem<String>(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 20),
                    const SizedBox(width: 8),
                    Text(controller.isDevBoard ? 'Restart' : 'New Game'),
                  ],
                ),
              ),
              // Export to Custom Board
              const PopupMenuItem<String>(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 20),
                    SizedBox(width: 8),
                    Text('Export to Custom Board'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.portrait) {
              return _buildPortraitLayout();
            } else {
              return _buildLandscapeLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // PERFORMANCE: Flexible instead of Expanded to prevent overflow
        const Flexible(
          flex: 1,
          fit: FlexFit.tight,
          child: InfoPanel(isTopPanel: true),
        ),
        const Expanded(
          flex: 6,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: ChessBoardWidget(),
            ),
          ),
        ),
        const Flexible(
          flex: 1,
          fit: FlexFit.tight,
          child: InfoPanel(isTopPanel: false),
        ),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        const Expanded(flex: 1, child: InfoPanel(isTopPanel: true)),
        Expanded(
          flex: 3,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Expanded(child: ChessBoardWidget()),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
        const Expanded(flex: 1, child: InfoPanel(isTopPanel: false)),
      ],
    );
  }

  Widget _buildActionButtons() {
    final controller = Get.find<Controller>();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => controller.resetGame(),
            icon: const Icon(Icons.refresh),
            label: Text(controller.isDevBoard ? 'Restart' : 'New Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => controller.undoLastMove(),
            icon: const Icon(Icons.undo),
            label: const Text('Undo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showGameInfo(),
            icon: const Icon(Icons.info),
            label: const Text('Info'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameInfo() {
    Get.dialog(
      AlertDialog(
        title: const Text('Chess Recast'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Chess Recast!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Currently playing with standard chess rules.'),
            SizedBox(height: 8),
            Text('Future updates will include:'),
            Text('• New piece movement patterns'),
            Text('• Innovative game mechanics'),
            Text('• Cross-platform compatibility'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('OK')),
        ],
      ),
    );
  }
}
