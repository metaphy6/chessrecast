import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../mods/mods_enum.dart';
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
              // Game Mod info card
              Obx(
                () => _GameModInfoCard(
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

              const SizedBox(height: 24),

              // Divider with text
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Online',
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
                title: 'Watch Engine Play',
                subtitle: 'Watch the chess engine play itself',
                icon: Icons.smart_toy,
                color: Colors.blueGrey.shade700,
                onTap: () {
                  Get.toNamed(
                    '/watch-engine',
                    arguments: {'gameType': controller.selectedGameType.value},
                  );
                },
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

class _GameModInfoCard extends StatelessWidget {
  final ModsEnum gameType;

  const _GameModInfoCard({required this.gameType});

  IconData _getModeIcon(ModsEnum mode) {
    switch (mode) {
      case ModsEnum.classic:
        return Icons.castle;
      case ModsEnum.mercenary:
        return Icons.shield;
      case ModsEnum.heir:
        return Icons.auto_awesome;
      case ModsEnum.truce:
        return Icons.handshake;
      case ModsEnum.friendlyFire:
        return Icons.local_fire_department;
      case ModsEnum.kingsBattle:
        return Icons.sports_mma;
      case ModsEnum.saveTheQueen:
        return Icons.favorite;
      case ModsEnum.succession:
        return Icons.escalator_warning;
    }
  }

  Color _getModeColor(ModsEnum mode) {
    switch (mode) {
      case ModsEnum.classic:
        return Colors.brown;
      case ModsEnum.mercenary:
        return Colors.indigo;
      case ModsEnum.heir:
        return Colors.purple;
      case ModsEnum.truce:
        return Colors.teal;
      case ModsEnum.friendlyFire:
        return Colors.deepOrange;
      case ModsEnum.kingsBattle:
        return Colors.amber;
      case ModsEnum.saveTheQueen:
        return Colors.pink;
      case ModsEnum.succession:
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
