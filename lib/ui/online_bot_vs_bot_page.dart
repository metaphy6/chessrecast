import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modes/modes_enum.dart';
import '../services/api_service.dart';

class OnlineBotVsBotPage extends StatefulWidget {
  const OnlineBotVsBotPage({super.key});

  @override
  State<OnlineBotVsBotPage> createState() => _OnlineBotVsBotPageState();
}

class _OnlineBotVsBotPageState extends State<OnlineBotVsBotPage> {
  final ApiService _apiService = ApiService();

  int _whiteDifficulty = 5;
  int _blackDifficulty = 5;
  ModesEnum _selectedMode = ModesEnum.classic;
  bool _autoPlay = true;
  int _moveDelay = 1000; // milliseconds

  bool _isCreating = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Bot vs Bot'),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // White Bot Section
                _buildBotSection(
                  title: 'White Bot',
                  color: Colors.white,
                  difficulty: _whiteDifficulty,
                  onChanged: (value) {
                    setState(() {
                      _whiteDifficulty = value.toInt();
                    });
                  },
                ),

                const SizedBox(height: 24),

                // Black Bot Section
                _buildBotSection(
                  title: 'Black Bot',
                  color: Colors.grey[850]!,
                  difficulty: _blackDifficulty,
                  onChanged: (value) {
                    setState(() {
                      _blackDifficulty = value.toInt();
                    });
                  },
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

                const SizedBox(height: 24),

                // Settings Section
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
                              Icons.settings,
                              color: Colors.brown[700],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Game Settings',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Auto Play Toggle
                        SwitchListTile(
                          title: const Text('Auto Play'),
                          subtitle: const Text('Bots play automatically'),
                          value: _autoPlay,
                          onChanged: (value) {
                            setState(() {
                              _autoPlay = value;
                            });
                          },
                        ),

                        if (_autoPlay) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Move Delay: ${_moveDelay}ms',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          Slider(
                            value: _moveDelay.toDouble(),
                            min: 100,
                            max: 5000,
                            divisions: 49,
                            label: '${_moveDelay}ms',
                            onChanged: (value) {
                              setState(() {
                                _moveDelay = value.toInt();
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fast (100ms)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Slow (5s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Status Message
                if (_statusMessage.isNotEmpty)
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(fontSize: 14, color: Colors.blue[900]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                if (_statusMessage.isNotEmpty) const SizedBox(height: 16),

                // Start Button
                ElevatedButton(
                  onPressed: _isCreating ? null : _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.play_arrow, size: 32),
                            SizedBox(width: 8),
                            Text(
                              'Start Battle',
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
                  'Watch two AI bots battle online in real-time',
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

  Widget _buildBotSection({
    required String title,
    required Color color,
    required int difficulty,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      color: Colors.white.withAlpha((0.9 * 255).round()),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.grey[400]!, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
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
                    color: _getDifficultyColor(difficulty),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _getDifficultyColor(
                          difficulty,
                        ).withAlpha((0.3 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '$difficulty',
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
                _getDifficultyLabel(difficulty),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _getDifficultyColor(difficulty),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _getDifficultyColor(difficulty),
                inactiveTrackColor: Colors.grey[300],
                thumbColor: _getDifficultyColor(difficulty),
                overlayColor: _getDifficultyColor(
                  difficulty,
                ).withAlpha((0.2 * 255).round()),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              ),
              child: Slider(
                value: difficulty.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: difficulty.toString(),
                onChanged: onChanged,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Beginner',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'Master',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(int difficulty) {
    if (difficulty <= 3) {
      return Colors.green;
    } else if (difficulty <= 6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getDifficultyLabel(int difficulty) {
    if (difficulty <= 2) {
      return 'Beginner';
    } else if (difficulty <= 4) {
      return 'Easy';
    } else if (difficulty <= 6) {
      return 'Intermediate';
    } else if (difficulty <= 8) {
      return 'Advanced';
    } else {
      return 'Master';
    }
  }

  Future<void> _startGame() async {
    setState(() {
      _isCreating = true;
      _statusMessage = 'Creating game...';
    });

    try {
      // Test connection
      final isReachable = await _apiService.testConnection();
      if (!isReachable) {
        throw Exception(
          'Backend server is not reachable at ${ApiService.baseUrl}\n'
          'Make sure Docker containers are running: docker-compose up -d',
        );
      }

      setState(() {
        _statusMessage = 'Logging in...';
      });

      // Login as guest
      await _apiService.loginAsGuest();

      setState(() {
        _statusMessage = 'Setting up bot battle...';
      });

      // Create bot vs bot game
      final result = await _apiService.createBotVsBotGame(
        mode: _selectedMode.toSnakeCase(),
        whiteDifficulty: _whiteDifficulty,
        blackDifficulty: _blackDifficulty,
        autoPlay: _autoPlay,
        moveDelay: _moveDelay,
      );

      final gameId = result['game_id'];

      setState(() {
        _statusMessage = 'Battle started! Game ID: $gameId';
      });

      // Navigate to spectator view
      Get.toNamed(
        '/game',
        arguments: {
          'gameType': _selectedMode,
          'isOnline': true,
          'isSpectator': true,
          'gameId': gameId,
        },
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isCreating = false;
      });

      Get.snackbar(
        'Failed to Start Battle',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        duration: const Duration(seconds: 5),
      );
    }
  }
}
