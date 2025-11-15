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
              Expanded(
                child: GetBuilder<OptionsController>(
                  id: 'mode_selection',
                  builder: (_) {
                    return ListView.builder(
                      itemCount: ModesEnum.values.length,
                      itemBuilder: (context, index) {
                        final gameType = ModesEnum.values[index];
                        final isSelected =
                            controller.selectedGameType.value == gameType;

                        return _ModeCard(
                          gameType: gameType,
                          isSelected: isSelected,
                          onTap: () => controller.selectGameType(gameType),
                        );
                      },
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
              if (AppConstants.enableDevBoard) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Get.toNamed(
                      '/dev-board',
                      arguments: {
                        'gameType': controller.selectedGameType.value,
                      },
                    );
                  },
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Dev Board Setup'),
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

class _ModeCard extends StatelessWidget {
  final ModesEnum gameType;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.gameType,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
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
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gameType.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Text(
                  gameType.description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
