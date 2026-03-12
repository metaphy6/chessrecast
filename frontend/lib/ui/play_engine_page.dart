import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../management/play_engine_controller.dart';
import '../management/controller.dart';
import '../board/pieces/piece_color.dart';
import '../engine/engine.dart';
import 'board.dart';

/// Page for playing against the chess engine.
class PlayEnginePage extends StatelessWidget {
  const PlayEnginePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure a fresh PlayEngineController
    if (Get.isRegistered<Controller>()) {
      Get.delete<Controller>(force: true);
    }
    final controller =
        Get.put<Controller>(PlayEngineController()) as PlayEngineController;
    controller.setBuildContext(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Play vs Engine',
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
        backgroundColor: Colors.indigo.shade800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          // Undo round
          Obx(
            () => IconButton(
              icon: const Icon(Icons.undo, color: Colors.white),
              onPressed: controller.canUndo && !controller.isThinking.value
                  ? () => controller.undoRound()
                  : null,
              tooltip: 'Undo round',
            ),
          ),
          // New game
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.resetGame(),
            tooltip: 'New game',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Engine info bar
            _EngineInfoBar(controller: controller),
            // Board
            const Expanded(
              flex: 5,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ChessBoardWidget(),
                ),
              ),
            ),
            // Settings panel
            _SettingsPanel(controller: controller),
          ],
        ),
      ),
    );
  }
}

// ─── Engine info bar ─────────────────────────────────────────────────────────

class _EngineInfoBar extends StatelessWidget {
  final PlayEngineController controller;
  const _EngineInfoBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Obx(() {
        final thinking = controller.isThinking.value;
        final depth = controller.lastDepth.value;
        final score = controller.lastScore.value;
        final nodes = controller.lastNodes.value;
        final ms = controller.lastTimeMs.value;

        return Row(
          children: [
            if (thinking)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            Text(
              thinking ? 'Thinking…' : 'Your turn',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (depth > 0) ...[
              _stat('Depth', '$depth'),
              _stat('Eval', _fmtScore(score)),
              _stat('Nodes', _fmtNodes(nodes)),
              _stat('Time', '${ms}ms'),
            ],
          ],
        );
      }),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static String _fmtScore(int score) {
    if (score.abs() > 90000) {
      final m = (100000 - score.abs() + 1) ~/ 2;
      return score > 0 ? 'M$m' : '-M$m';
    }
    final cp = score / 100.0;
    return '${cp >= 0 ? '+' : ''}${cp.toStringAsFixed(1)}';
  }

  static String _fmtNodes(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

// ─── Settings panel ────────────────────────────────────────────────────────

class _SettingsPanel extends StatelessWidget {
  final PlayEngineController controller;
  const _SettingsPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          // Colour picker
          Expanded(
            child: Obx(
              () => InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'You play',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PieceColor>(
                    value: controller.humanColor.value,
                    isDense: true,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: PieceColor.white,
                        child: Text('White', style: TextStyle(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: PieceColor.black,
                        child: Text('Black', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        controller.setHumanColor(v);
                        controller.resetGame();
                        controller.startIfEngineFirst();
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Engine level
          Expanded(
            child: Obx(
              () => InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Engine',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<EngineLevel>(
                    value: controller.engineLevel.value,
                    isDense: true,
                    isExpanded: true,
                    items: EngineLevel.values
                        .map(
                          (l) => DropdownMenuItem(
                            value: l,
                            child: Text(
                              l.name[0].toUpperCase() + l.name.substring(1),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) controller.setEngineLevel(v);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
