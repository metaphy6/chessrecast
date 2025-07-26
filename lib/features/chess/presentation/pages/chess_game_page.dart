import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/chess_controller.dart';
import '../widgets/chess_board_widget.dart';
import '../widgets/game_info_panel.dart';

class ChessGamePage extends StatelessWidget {
  const ChessGamePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ChessController>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chess Recast',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
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
          onPressed: () => Get.offAllNamed('/'),
          tooltip: 'Back to Game Selection',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.resetGame(),
            tooltip: 'New Game',
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () => controller.undoLastMove(),
            tooltip: 'Undo Move',
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
        const Expanded(flex: 1, child: GameInfoPanel(isTopPanel: true)),
        const Expanded(
          flex: 6,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: ChessBoardWidget(),
            ),
          ),
        ),
        const Expanded(flex: 1, child: GameInfoPanel(isTopPanel: false)),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        const Expanded(flex: 1, child: GameInfoPanel(isTopPanel: true)),
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
        const Expanded(flex: 1, child: GameInfoPanel(isTopPanel: false)),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => Get.find<ChessController>().resetGame(),
            icon: const Icon(Icons.refresh),
            label: const Text('New Game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Get.find<ChessController>().undoLastMove(),
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
