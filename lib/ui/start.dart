import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import '../management/options.dart';
import '../constants.dart';

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OptionsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Recast - Game Selection'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Choose Your Game Mode',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // PERFORMANCE: ListView without GetBuilder - individual cards rebuild themselves
              Expanded(
                child: ListView.builder(
                  itemCount: ModesEnum.values.length,
                  // PERFORMANCE: Cache extent to reduce rebuilds
                  cacheExtent: 500,
                  // PERFORMANCE: Keep repaint boundaries enabled for items
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    final gameType = ModesEnum.values[index];

                    // PERFORMANCE: Each card manages its own rebuild via GetBuilder
                    return RepaintBoundary(
                      child: _ModeCard(
                        key: ValueKey(gameType),
                        gameType: gameType,
                        controller: controller,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                return ElevatedButton(
                  onPressed: controller.startGame,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Start ${controller.selectedGameType.value.displayName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              // Bot vs Bot Button
              OutlinedButton.icon(
                onPressed: () {
                  Get.toNamed(
                    '/bot-setup',
                    arguments: {'gameType': controller.selectedGameType.value},
                  );
                },
                icon: const Icon(Icons.smart_toy),
                label: const Text('🤖 Bot vs Bot'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.blue.shade600, width: 2),
                  foregroundColor: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 12),
              // Play Online Against Bot Button
              OutlinedButton.icon(
                onPressed: () {
                  Get.toNamed('/bot-selection');
                },
                icon: const Icon(Icons.cloud),
                label: const Text('🌐 Play Online vs Bot'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.green.shade600, width: 2),
                  foregroundColor: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 12),
              // Online Bot vs Bot Button
              OutlinedButton.icon(
                onPressed: () {
                  Get.toNamed('/online-bot-vs-bot');
                },
                icon: const Icon(Icons.smart_toy),
                label: const Text('⚔️ Watch Online Bot Battle'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.orange.shade600, width: 2),
                  foregroundColor: Colors.orange.shade600,
                ),
              ),
              if (AppConstants.enableDevBoard) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Get.toNamed(
                      '/custom-board',
                      arguments: {
                        'gameType': controller.selectedGameType.value,
                      },
                    );
                  },
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Custom Board Setup'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.purple.shade600, width: 2),
                    foregroundColor: Colors.purple.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// PERFORMANCE: Optimized mode card that only rebuilds itself when selection changes
class _ModeCard extends StatelessWidget {
  final ModesEnum gameType;
  final OptionsController controller;

  const _ModeCard({
    super.key,
    required this.gameType,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: Cache theme colors outside GetBuilder to avoid repeated lookups
    final primaryColor = Theme.of(context).colorScheme.primary;
    final greyColor = Colors.grey.shade600;
    final titleStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
    final descStyle = TextStyle(color: greyColor, fontSize: 14);

    // PERFORMANCE: Only this card rebuilds when selection changes
    return GetBuilder<OptionsController>(
      id: 'mode_${gameType.name}',
      builder: (_) {
        final isSelected = controller.selectedGameType.value == gameType;

        // PERFORMANCE: Use a simple Container to avoid layout animation; keep card constant
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            elevation: 2,
            color: null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.selectGameType(gameType),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected ? primaryColor : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(gameType.displayName, style: titleStyle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: Text(gameType.description, style: descStyle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
