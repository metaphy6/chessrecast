import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import '../management/options.dart';

class GameModeSelectionPage extends StatelessWidget {
  const GameModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OptionsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Chess Recast'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            // Header section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.extension,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Choose Your Game Mode',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a mode to explore unique chess variants',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Game modes grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: ModesEnum.values.length,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final gameType = ModesEnum.values[index];
                    return _GameModeCard(
                      key: ValueKey(gameType),
                      gameType: gameType,
                      controller: controller,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _GameModeCard extends StatelessWidget {
  final ModesEnum gameType;
  final OptionsController controller;

  const _GameModeCard({
    super.key,
    required this.gameType,
    required this.controller,
  });

  IconData _getModeIcon(ModesEnum mode) {
    switch (mode) {
      case ModesEnum.classic:
        return Icons.castle;
      case ModesEnum.mercenary:
        return Icons.shield;
      // case ModesEnum.coyote: // DISABLED MODE
      //   return Icons.speed;
      case ModesEnum.heir:
        return Icons.auto_awesome;
      case ModesEnum.truce:
        return Icons.handshake;
      // case ModesEnum.snare: // DISABLED MODE
      //   return Icons.gps_fixed;
      // case ModesEnum.diamonds: // DISABLED MODE
      //   return Icons.diamond;
      // case ModesEnum.secretPassage: // DISABLED MODE
      //   return Icons.swap_horiz;
      case ModesEnum.friendlyFire:
        return Icons.local_fire_department;
      case ModesEnum.kingsBattle:
        return Icons.sports_mma;
      case ModesEnum.saveTheQueen:
        return Icons.favorite;
      case ModesEnum.succession:
        return Icons.escalator_warning;
    }
  }

  Color _getModeColor(ModesEnum mode) {
    switch (mode) {
      case ModesEnum.classic:
        return Colors.brown;
      case ModesEnum.mercenary:
        return Colors.indigo;
      // case ModesEnum.coyote: // DISABLED MODE
      //   return Colors.orange;
      case ModesEnum.heir:
        return Colors.purple;
      case ModesEnum.truce:
        return Colors.teal;
      // case ModesEnum.snare: // DISABLED MODE
      //   return Colors.red;
      // case ModesEnum.diamonds: // DISABLED MODE
      //   return Colors.blue;
      // case ModesEnum.secretPassage: // DISABLED MODE
      //   return Colors.green;
      case ModesEnum.friendlyFire:
        return Colors.deepOrange;
      case ModesEnum.kingsBattle:
        return Colors.amber;
      case ModesEnum.saveTheQueen:
        return Colors.pink;
      case ModesEnum.succession:
        return Colors.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = _getModeColor(gameType);
    final modeIcon = _getModeIcon(gameType);

    return GetBuilder<OptionsController>(
      id: 'mode_${gameType.name}',
      builder: (_) {
        final isSelected = controller.selectedGameType.value == gameType;

        return GestureDetector(
          onTap: () {
            controller.selectGameType(gameType);
            // Navigate to play options after selection
            Get.toNamed('/play-options');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? modeColor.withValues(alpha: 0.15)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? modeColor : Colors.grey.shade300,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: modeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: modeColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(modeIcon, size: 32, color: modeColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    gameType.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? modeColor : null,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      gameType.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
