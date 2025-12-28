import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import '../management/options.dart';
import '../constants.dart';

class PlayOptionsPage extends StatelessWidget {
  const PlayOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<OptionsController>();

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.selectedGameType.value.displayName)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Game mode info card
              Obx(
                () => _GameModeInfoCard(
                  gameType: controller.selectedGameType.value,
                ),
              ),
              const SizedBox(height: 32),

              // Section title
              const Text(
                'How would you like to play?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Primary action - Local Game
              _PlayOptionCard(
                title: 'Start Local Game',
                subtitle: 'Play on the same device',
                icon: Icons.people,
                color: Colors.blue.shade600,
                isPrimary: true,
                onTap: () => controller.startGame(),
              ),
              const SizedBox(height: 16),

              // AI Options
              _PlayOptionCard(
                title: 'Play vs AI (Neural Network)',
                subtitle: 'Challenge our trained AI opponent',
                icon: Icons.psychology,
                color: Colors.purple.shade600,
                onTap: () {
                  Get.toNamed(
                    '/ai-setup',
                    arguments: {'gameType': controller.selectedGameType.value},
                  );
                },
              ),
              const SizedBox(height: 12),

              _PlayOptionCard(
                title: 'Bot vs Bot',
                subtitle: 'Watch two bots battle it out',
                icon: Icons.smart_toy,
                color: Colors.indigo.shade600,
                onTap: () {
                  Get.toNamed(
                    '/bot-setup',
                    arguments: {'gameType': controller.selectedGameType.value},
                  );
                },
              ),
              const SizedBox(height: 24),

              // Divider with text
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Online & Training',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Online options
              _PlayOptionCard(
                title: 'Play Online vs Bot',
                subtitle: 'Play against a cloud-hosted bot',
                icon: Icons.cloud,
                color: Colors.green.shade600,
                onTap: () => Get.toNamed('/bot-selection'),
              ),
              const SizedBox(height: 12),

              _PlayOptionCard(
                title: 'Watch Online Bot Battle',
                subtitle: 'Spectate online bot matches',
                icon: Icons.visibility,
                color: Colors.orange.shade600,
                onTap: () {
                  Get.toNamed(
                    '/online-bot-vs-bot',
                    arguments: {'gameType': controller.selectedGameType.value},
                  );
                },
              ),
              const SizedBox(height: 12),

              _PlayOptionCard(
                title: 'Watch AI Training',
                subtitle: 'View saved training games',
                icon: Icons.school,
                color: Colors.teal.shade600,
                onTap: () => Get.toNamed('/training-viewer'),
              ),
              const SizedBox(height: 12),

              _PlayOptionCard(
                title: 'Watch Live Training',
                subtitle: 'Real-time AI training stream',
                icon: Icons.live_tv,
                color: Colors.red.shade600,
                onTap: () => Get.toNamed('/live-training-viewer'),
              ),

              // Dev options
              if (AppConstants.enableDevBoard) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Developer',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                _PlayOptionCard(
                  title: 'Custom Board Setup',
                  subtitle: 'Debug and test board positions',
                  icon: Icons.bug_report,
                  color: Colors.grey.shade700,
                  onTap: () {
                    Get.toNamed(
                      '/custom-board',
                      arguments: {
                        'gameType': controller.selectedGameType.value,
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameModeInfoCard extends StatelessWidget {
  final ModesEnum gameType;

  const _GameModeInfoCard({required this.gameType});

  IconData _getModeIcon(ModesEnum mode) {
    switch (mode) {
      case ModesEnum.classic:
        return Icons.castle;
      case ModesEnum.mercenary:
        return Icons.shield;
      case ModesEnum.coyote:
        return Icons.speed;
      case ModesEnum.heir:
        return Icons.auto_awesome;
      case ModesEnum.truce:
        return Icons.handshake;
      case ModesEnum.snare:
        return Icons.gps_fixed;
      case ModesEnum.diamonds:
        return Icons.diamond;
      case ModesEnum.secretPassage:
        return Icons.swap_horiz;
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
      case ModesEnum.coyote:
        return Colors.orange;
      case ModesEnum.heir:
        return Colors.purple;
      case ModesEnum.truce:
        return Colors.teal;
      case ModesEnum.snare:
        return Colors.red;
      case ModesEnum.diamonds:
        return Colors.blue;
      case ModesEnum.secretPassage:
        return Colors.green;
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
    final color = _getModeColor(gameType);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_getModeIcon(gameType), size: 40, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameType.displayName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  gameType.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _PlayOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
