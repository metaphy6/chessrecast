import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import 'shared.dart';

class BotSelectionPage extends StatefulWidget {
  const BotSelectionPage({super.key});

  @override
  State<BotSelectionPage> createState() => _BotSelectionPageState();
}

class _BotSelectionPageState extends State<BotSelectionPage> {
  int _selectedDifficulty = 5;
  ModesEnum _selectedMode = ModesEnum.classic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge Bot'),
        backgroundColor: Colors.brown[700],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.brown[700]!, Colors.brown[900]!],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Difficulty Section (refactored with shared widgets)
                SectionCard(
                  titleRow: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: Colors.brown[700],
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Bot Difficulty',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[900],
                        ),
                      ),
                    ],
                  ),
                  child: DifficultySelector(
                    difficulty: _selectedDifficulty,
                    onChanged: (value) =>
                        setState(() => _selectedDifficulty = value.toInt()),
                  ),
                ),

                const SizedBox(height: 24),

                // Game Mode Section
                Card(
                  color: Colors.white.withAlpha((0.9 * 255).round()),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.games,
                              color: Colors.brown[700],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Game Mode',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ModesEnum>(
                          value: _selectedMode,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: ModesEnum.values.map((mode) {
                            return DropdownMenuItem(
                              value: mode,
                              child: Text(
                                mode.displayName,
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMode = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Start Button
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.play_arrow, size: 32),
                      SizedBox(width: 8),
                      Text(
                        'Start Game',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Info Text
                Text(
                  'You will play online against the backend AI bot',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha((0.8 * 255).round()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Colors and labels now handled by shared DifficultySelector

  // Difficulty label is provided by DifficultyLabel widget.

  void _startGame() {
    // Navigate to game board with online controller
    Get.toNamed(
      '/game',
      arguments: {
        'gameType': _selectedMode,
        'isOnline': true,
        'botDifficulty': _selectedDifficulty,
      },
    );
  }
}
