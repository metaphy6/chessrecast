import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../mods/enums.dart';
import 'shared.dart';
import '../services/api_service.dart';

class OnlineBotVsBot extends StatefulWidget {
  const OnlineBotVsBot({super.key});

  @override
  State<OnlineBotVsBot> createState() => _OnlineBotVsBotState();
}

class _OnlineBotVsBotState extends State<OnlineBotVsBot> {
  final ApiService _apiService = ApiService();

  int _whiteDifficulty = 5;
  int _blackDifficulty = 5;
  ModsEnum _selectedMode = ModsEnum.classic;
  bool _autoPlay = true;
  int _moveDelaySeconds = 3; // seconds (1-10)

  bool _isCreating = false;
  bool _isGameRunning = false;
  bool _isPaused = false;
  String _statusMessage = '';
  String? _currentGameId;

  @override
  void initState() {
    super.initState();
    // Check if Game Mod was passed from home screen
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map) {
      if (arguments.containsKey('gameType')) {
        final gameType = arguments['gameType'];
        if (gameType is ModsEnum) {
          _selectedMode = gameType;
        }
      }
    }
  }

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

                // Game Mod Section
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
                              'Game Mod',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ModsEnum>(
                          initialValue: _selectedMode,
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
                          items: ModsEnum.values.map((mode) {
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
                          Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: Colors.brown[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Move Delay: $_moveDelaySeconds second${_moveDelaySeconds > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.brown[600],
                              inactiveTrackColor: Colors.brown[200],
                              thumbColor: Colors.brown[700],
                              overlayColor: Colors.brown.withAlpha(50),
                              valueIndicatorColor: Colors.brown[700],
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: _moveDelaySeconds.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: '$_moveDelaySeconds sec',
                              onChanged: (value) {
                                setState(() {
                                  _moveDelaySeconds = value.toInt();
                                });
                                // If game is running, update delay in real-time
                                if (_isGameRunning && _currentGameId != null) {
                                  _updateMoveDelay();
                                }
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Fast (1s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Slow (10s)',
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

                // Game Control Buttons
                if (_isGameRunning) ...[
                  // Play/Pause and Stop buttons when game is running
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _togglePause,
                          icon: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            size: 28,
                          ),
                          label: Text(
                            _isPaused ? 'Resume' : 'Pause',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isPaused
                                ? Colors.green[600]
                                : Colors.orange[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _stopGame,
                          icon: const Icon(Icons.stop, size: 28),
                          label: const Text(
                            'Stop',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Start Button when no game is running
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
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
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
                ],

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
            DifficultySelector(difficulty: difficulty, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  // Difficulty label & color mapping now handled by shared DifficultySelector

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

      // Create bot vs bot game with delay in milliseconds
      final result = await _apiService.createBotVsBotGame(
        mode: _selectedMode.toSnakeCase(),
        whiteDifficulty: _whiteDifficulty,
        blackDifficulty: _blackDifficulty,
        autoPlay: _autoPlay,
        moveDelay: _moveDelaySeconds * 1000, // Convert seconds to ms
      );

      final gameId = result['game_id'];
      _currentGameId = gameId;

      setState(() {
        _statusMessage = 'Battle started! Game ID: $gameId';
        _isGameRunning = true;
        _isPaused = false;
        _isCreating = false;
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
        _isGameRunning = false;
      });

      // Use ScaffoldMessenger instead of Get.snackbar to avoid Overlay issues
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to Start Battle: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _togglePause() async {
    if (_currentGameId == null) return;

    try {
      if (_isPaused) {
        await _apiService.resumeGame(_currentGameId!);
        setState(() {
          _isPaused = false;
          _statusMessage = 'Game resumed';
        });
      } else {
        await _apiService.pauseGame(_currentGameId!);
        setState(() {
          _isPaused = true;
          _statusMessage = 'Game paused';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _stopGame() async {
    if (_currentGameId == null) return;

    try {
      await _apiService.stopGame(_currentGameId!);
      setState(() {
        _isGameRunning = false;
        _isPaused = false;
        _currentGameId = null;
        _statusMessage = 'Game stopped';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping game: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _updateMoveDelay() async {
    if (_currentGameId == null) return;

    try {
      await _apiService.setMoveDelay(_currentGameId!, _moveDelaySeconds * 1000);
    } catch (e) {
      // Silently fail - delay update is not critical
    }
  }
}
