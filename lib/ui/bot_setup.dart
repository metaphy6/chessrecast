import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../bot/bot_manager.dart';
import '../modes/modes_enum.dart';
import '../routes.dart';

class BotSetupScreen extends StatefulWidget {
  const BotSetupScreen({super.key});

  @override
  State<BotSetupScreen> createState() => _BotSetupScreenState();
}

class _BotSetupScreenState extends State<BotSetupScreen> {
  final BotManager _botManager = Get.find<BotManager>();

  BotType _whiteBot = BotType.greedy;
  BotType _blackBot = BotType.random;
  late ModesEnum _selectedMode;
  int _moveDelay = 1000;
  bool _autoPlay = true;

  @override
  void initState() {
    super.initState();
    // Get the game type from route arguments, default to classic if not provided
    final args = Get.arguments as Map<String, dynamic>?;
    _selectedMode = args?['gameType'] ?? ModesEnum.classic;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bot vs Bot Setup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              '🤖 Bot Battle Configuration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // White Bot Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'White Bot',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BotType>(
                      value: _whiteBot,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Bot Type',
                      ),
                      items: BotType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _whiteBot = value);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _whiteBot.description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Black Bot Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Black Bot',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<BotType>(
                      value: _blackBot,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Bot Type',
                      ),
                      items: BotType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _blackBot = value);
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _blackBot.description,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Game Mode Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Game Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ModesEnum>(
                      value: _selectedMode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Select Mode',
                      ),
                      items: ModesEnum.values.map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedMode = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Auto-play Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Playback Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Auto-play'),
                      subtitle: const Text('Automatically play moves'),
                      value: _autoPlay,
                      onChanged: (value) {
                        setState(() => _autoPlay = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Move Delay: ${_moveDelay}ms'),
                    Slider(
                      value: _moveDelay.toDouble(),
                      min: 100,
                      max: 3000,
                      divisions: 29,
                      label: '${_moveDelay}ms',
                      onChanged: (value) {
                        setState(() => _moveDelay = value.toInt());
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Start Button
            ElevatedButton.icon(
              onPressed: _startBotGame,
              icon: const Icon(Icons.play_arrow, size: 32),
              label: const Text(
                'Start Bot Battle',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startBotGame() {
    // Configure bot manager
    _botManager.setupBotVsBot(
      whiteType: _whiteBot,
      blackType: _blackBot,
      gameMode: _selectedMode,
    );

    _botManager.moveDelay.value = _moveDelay;

    if (_autoPlay) {
      _botManager.startAutoPlay();
    }

    // Navigate to chess game
    Get.toNamed(
      AppRoutes.chess,
      arguments: {'gameType': _selectedMode, 'isDevBoard': false},
    );
  }
}
