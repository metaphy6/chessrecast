import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modes/modes_enum.dart';

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
                // Difficulty Section
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
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getDifficultyColor().withAlpha(
                                      (0.3 * 255).round(),
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$_selectedDifficulty',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _getDifficultyLabel(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _getDifficultyColor(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: _getDifficultyColor(),
                            inactiveTrackColor: Colors.grey[300],
                            thumbColor: _getDifficultyColor(),
                            overlayColor: _getDifficultyColor().withAlpha(
                              (0.2 * 255).round(),
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 14,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 24,
                            ),
                          ),
                          child: Slider(
                            value: _selectedDifficulty.toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _selectedDifficulty.toString(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDifficulty = value.toInt();
                              });
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Beginner',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              'Master',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

  Color _getDifficultyColor() {
    if (_selectedDifficulty <= 3) {
      return Colors.green;
    } else if (_selectedDifficulty <= 6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getDifficultyLabel() {
    if (_selectedDifficulty <= 2) {
      return 'Beginner';
    } else if (_selectedDifficulty <= 4) {
      return 'Easy';
    } else if (_selectedDifficulty <= 6) {
      return 'Intermediate';
    } else if (_selectedDifficulty <= 8) {
      return 'Advanced';
    } else {
      return 'Master';
    }
  }

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
