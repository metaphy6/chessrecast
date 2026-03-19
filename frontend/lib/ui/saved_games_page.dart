import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../mods/mods_enum.dart';
import '../routes.dart';
import '../services/saved_game.dart';
import '../services/saved_games_service.dart';

class SavedGamesPage extends StatelessWidget {
  const SavedGamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<SavedGamesService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Games'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        actions: [
          Obx(() {
            if (service.games.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Delete all',
              onPressed: () => _confirmDeleteAll(context, service),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (service.games.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videogame_asset_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No saved games yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Watch an engine game to completion\nand it will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: service.games.length,
          itemBuilder: (context, index) {
            final game = service.games[index];
            return _GameTile(game: game, service: service);
          },
        );
      }),
    );
  }

  void _confirmDeleteAll(BuildContext context, SavedGamesService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all saved games?'),
        content: Text('${service.games.length} games will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              service.deleteAll();
            },
            child: const Text(
              'Delete all',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final SavedGame game;
  final SavedGamesService service;

  const _GameTile({required this.game, required this.service});

  @override
  Widget build(BuildContext context) {
    final date = _formatDate(game.timestamp);
    final resultColor = game.result == 'white'
        ? Colors.green
        : game.result == 'black'
        ? Colors.red
        : Colors.orange;

    return Dismissible(
      key: ValueKey(game.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => service.deleteGame(game.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          onTap: () => _showGameDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: resultColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      game.resultLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_capitalize(game.whiteLevel)} (W) vs ${_capitalize(game.blackLevel)} (B)  ·  '
                  '${game.totalMoves} moves  ·  ${game.gameType}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGameDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) =>
            _GameDetailSheet(game: game, scrollCtrl: scrollCtrl),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _GameDetailSheet extends StatelessWidget {
  final SavedGame game;
  final ScrollController scrollCtrl;

  const _GameDetailSheet({required this.game, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.resultLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_capitalize(game.whiteLevel)} vs ${_capitalize(game.blackLevel)}  ·  '
                      '${game.totalMoves} moves',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (game.finalFEN != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    final modsEnum = ModsEnum.values.firstWhere(
                      (m) => m.name == game.gameType,
                      orElse: () => ModsEnum.classic,
                    );
                    Get.toNamed(
                      AppRoutes.customBoard,
                      arguments: {
                        'fen': game.finalFEN,
                        'gameType': modsEnum,
                      },
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Analyze'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Move log
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: game.moveLog.length,
            itemBuilder: (_, i) {
              final line = game.moveLog[i];
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
          ),
        ),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
