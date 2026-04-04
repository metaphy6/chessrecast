import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../management/watch_engine_controller.dart';
import '../management/controller.dart';
import '../engine/engine.dart';
import '../routes.dart';
import 'board.dart';

/// Page for watching the engine play against itself.
///
/// Shows the board, live search stats (depth, score, nodes),
/// playback controls (play/pause, speed, step), a scrolling move log,
/// and a running scoreboard (W-D-L) across auto-restarted games.
class WatchEngine extends StatelessWidget {
  const WatchEngine({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure a fresh WatchEngineController — delete any stale Controller
    // left over from a previous page (game page, custom board, etc.).
    if (Get.isRegistered<Controller>()) {
      Get.delete<Controller>(force: true);
    }
    final controller =
        Get.put<Controller>(WatchEngineController()) as WatchEngineController;
    controller.setBuildContext(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Engine Lab',
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
        backgroundColor: Colors.blueGrey.shade800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            controller.stopPlaying();
            Get.back();
          },
        ),
        actions: [
          // Play / Pause / Start toggle
          Obx(() {
            final playing = controller.isPlaying.value;
            final paused = controller.isPaused.value;
            return IconButton(
              icon: Icon(
                playing && !paused ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                if (!playing) {
                  controller.startPlaying();
                } else if (paused) {
                  controller.resume();
                } else {
                  controller.pause();
                }
              },
              tooltip: playing && !paused
                  ? 'Pause'
                  : (playing ? 'Resume' : 'Start'),
            );
          }),
          // Stop
          Obx(
            () => IconButton(
              icon: const Icon(Icons.stop, color: Colors.white),
              onPressed: controller.isPlaying.value
                  ? () => controller.stopPlaying()
                  : null,
              tooltip: 'Stop',
            ),
          ),
          // Step one move
          Obx(
            () => IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed:
                  controller.isPaused.value || !controller.isPlaying.value
                  ? () => controller.stepOneMove()
                  : null,
              tooltip: 'Step one move',
            ),
          ),
          // New game
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => controller.restartGame(),
            tooltip: 'New game',
          ),
          // Analyze position in custom board
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: () {
              controller.stopPlaying();
              final history = controller.boardFenHistory;
              Get.toNamed(
                AppRoutes.customBoard,
                arguments: {
                  'fen': controller.board.toFEN(),
                  'gameType': controller.gameType,
                  'fenHistory': history,
                },
              );
            },
            tooltip: 'Analyze position',
          ),
          // Saved games history
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => Get.toNamed(AppRoutes.savedGames),
            tooltip: 'Saved games',
          ),
        ],
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.portrait) {
              return _buildPortrait(controller);
            } else {
              return _buildLandscape(controller);
            }
          },
        ),
      ),
    );
  }

  // ── Portrait layout ────────────────────────────────────────────────────

  Widget _buildPortrait(WatchEngineController c) {
    return Column(
      children: [
        // Stats bar
        _StatsBar(controller: c),
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
        // Controls + log
        Expanded(flex: 4, child: _BottomPanel(controller: c)),
      ],
    );
  }

  // ── Landscape layout ───────────────────────────────────────────────────

  Widget _buildLandscape(WatchEngineController c) {
    return Row(
      children: [
        // Board
        const Expanded(
          flex: 5,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: ChessBoardWidget(),
            ),
          ),
        ),
        // Side panel
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _StatsBar(controller: c),
              Expanded(child: _BottomPanel(controller: c)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Live Stats Bar ────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final WatchEngineController controller;
  const _StatsBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Obx(() {
        final score = controller.lastScore.value;
        final depth = controller.lastDepth.value;
        final nodes = controller.lastNodes.value;
        final moves = controller.totalMoves.value;

        return Row(
          children: [
            _stat('Depth', '$depth'),
            _stat('Eval', _fmtScore(score)),
            _stat('Nodes', _fmtNodes(nodes)),
            _stat('Moves', '$moves'),
            const Spacer(),
            // Scoreboard
            _scoreboard(controller),
          ],
        );
      }),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
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

  Widget _scoreboard(WatchEngineController c) {
    return Obx(
      () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'W${c.whiteWins.value}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            ' D${c.draws.value} ',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          Text(
            'B${c.blackWins.value}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            ' (${c.gamesPlayed.value})',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
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

// ─── Bottom panel: controls + move log ─────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final WatchEngineController controller;
  const _BottomPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ControlsRow(controller: controller),
        const Divider(height: 1),
        Expanded(child: _MoveLog(controller: controller)),
      ],
    );
  }
}

// ─── Controls ──────────────────────────────────────────────────────────────

class _ControlsRow extends StatelessWidget {
  final WatchEngineController controller;
  const _ControlsRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speed slider
          Obx(
            () => Row(
              children: [
                const Icon(Icons.speed, size: 18),
                const SizedBox(width: 4),
                const Text('Speed', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: controller.moveDelayMs.value.toDouble(),
                    min: 100,
                    max: 3000,
                    divisions: 29,
                    label: '${controller.moveDelayMs.value}ms',
                    onChanged: (v) => controller.setMoveDelay(v.toInt()),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${controller.moveDelayMs.value}ms',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Engine level selectors
          Row(
            children: [
              Expanded(
                child: _LevelDropdown(
                  label: 'White',
                  level: controller.whiteLevel,
                  onChanged: controller.setWhiteLevel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LevelDropdown(
                  label: 'Black',
                  level: controller.blackLevel,
                  onChanged: controller.setBlackLevel,
                ),
              ),
              const SizedBox(width: 8),
              // Auto-restart toggle
              Obx(
                () => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Loop', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: controller.autoRestart.value,
                      onChanged: (v) => controller.autoRestart.value = v,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelDropdown extends StatelessWidget {
  final String label;
  final Rx<EngineLevel> level;
  final void Function(EngineLevel) onChanged;

  const _LevelDropdown({
    required this.label,
    required this.level,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<EngineLevel>(
            value: level.value,
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
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

// ─── Move Log ──────────────────────────────────────────────────────────────

class _MoveLog extends StatefulWidget {
  final WatchEngineController controller;
  const _MoveLog({required this.controller});

  @override
  State<_MoveLog> createState() => _MoveLogState();
}

class _MoveLogState extends State<_MoveLog> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: Obx(() {
        final log = widget.controller.moveLog;

        // Auto-scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });

        if (log.isEmpty) {
          return const Center(
            child: Text(
              'Waiting for first move…',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: log.length,
          itemBuilder: (_, i) {
            final line = log[i];
            final isResult = line.startsWith('──');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                line,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isResult ? Colors.deepOrange : Colors.black87,
                  fontWeight: isResult ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
