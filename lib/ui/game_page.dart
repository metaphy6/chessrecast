import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../management/controller.dart';
import '../bot/bot_manager.dart';
import 'board.dart';
import 'info_panel.dart';

class ChessGamePage extends StatelessWidget {
  const ChessGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<Controller>();
    final botManager = Get.find<BotManager>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Chess Recast',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
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
          Obx(
            () => IconButton(
              icon: const Icon(Icons.undo, color: Colors.white),
              onPressed: controller.canUndo
                  ? () => controller.undoLastMove()
                  : null,
              tooltip: 'Undo Move',
            ),
          ),
          Obx(
            () => IconButton(
              icon: const Icon(Icons.redo, color: Colors.white),
              onPressed: controller.canRedo
                  ? () => controller.redoMove()
                  : null,
              tooltip: 'Redo Move',
            ),
          ),
          // Bot Controls (only show if bot game)
          Obx(() {
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
                    ),
                    onPressed: () {
                      if (botManager.isPaused.value) {
                        botManager.resumeAutoPlay();
                      } else {
                        botManager.pauseAutoPlay();
                      }
                    },
                    tooltip: botManager.isPaused.value ? 'Resume' : 'Pause',
                  ),
                // Speed control
                PopupMenuButton<int>(
                  icon: const Icon(Icons.speed, color: Colors.white),
                  tooltip: 'Bot Speed',
                  onSelected: (speed) {
                    botManager.moveDelay.value = speed;
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 100,
                      child: Text('Very Fast (0.1s)'),
                    ),
                    const PopupMenuItem(value: 500, child: Text('Fast (0.5s)')),
                    const PopupMenuItem(
                      value: 1000,
                      child: Text('Normal (1s)'),
                    ),
                    const PopupMenuItem(value: 2000, child: Text('Slow (2s)')),
                    const PopupMenuItem(
                      value: 3000,
                      child: Text('Very Slow (3s)'),
                    ),
                  ],
                ),
              ],
            );
          }),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.resetGame(),
            tooltip: controller.isDevBoard ? 'Restart' : 'New Game',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = constraints.maxHeight > constraints.maxWidth;

            if (isPortrait) {
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
        const Expanded(flex: 1, child: InfoPanel(isTopPanel: true)),
        const Expanded(
          flex: 6,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: ChessBoardWidget(),
            ),
          ),
        ),
        const Expanded(flex: 1, child: InfoPanel(isTopPanel: false)),
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
            onPressed: () => Get.find<Controller>().undoLastMove(),
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
