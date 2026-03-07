import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../debug.dart';

/// API Service for communicating with the ChessRecast Go backend
class ApiService {
  // Manual override for testing - set this if auto-detection doesn't work
  static String? manualBaseUrl;

  // Backend URL - automatically detects the correct URL based on platform
  static String get baseUrl {
    // Use manual override if set
    if (manualBaseUrl != null) return manualBaseUrl!;

    // For web or desktop (Windows, macOS, Linux)
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'http://localhost:8080/api/v1';
    }
    // For Android emulator - try 10.0.2.2 first
    else if (Platform.isAndroid) {
      // 10.0.2.2 is the special alias to host loopback interface
      return 'http://10.0.2.2:8080/api/v1';
    }
    // For iOS simulator
    else if (Platform.isIOS) {
      return 'http://localhost:8080/api/v1';
    }
    // Fallback
    return 'http://localhost:8080/api/v1';
  }

  String? _authToken;
  String? _userId;

  /// Login as guest user
  Future<Map<String, dynamic>> loginAsGuest() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/guest'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _authToken = data['token'];
        _userId = data['user_id'];
        return data;
      }
      throw Exception('Failed to login: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Create a new game
  /// [mode] - Game Mod (e.g., 'classic', 'mercenary')
  /// [botDifficulty] - AI difficulty level (1-10), null for PvP
  /// [opponentId] - Opponent player ID for PvP, null for bot game
  /// Returns game data including game_id and player_id
  Future<Map<String, dynamic>> createGame({
    required String mode,
    int? botDifficulty,
    String? opponentId,
  }) async {
    final body = <String, dynamic>{'mode': mode};

    if (botDifficulty != null) {
      body['bot_difficulty'] = botDifficulty;
    }
    if (opponentId != null) {
      body['opponent_id'] = opponentId;
    }

    logApi('Creating game: mode=$mode');
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data;
    }
    throw Exception('Failed to create game: ${response.body}');
  }

  /// Get current game state
  Future<Map<String, dynamic>> getGame(String gameId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/$gameId'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get game: ${response.statusCode}');
  }

  /// List all active games
  Future<List<Map<String, dynamic>>> listGames() async {
    final response = await http.get(
      Uri.parse('$baseUrl/games'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['games'] ?? []);
    }
    throw Exception('Failed to list games');
  }

  /// Make a move in a game
  /// [gameId] - Game ID
  /// [from] - Source position in algebraic notation (e.g., 'e2')
  /// [to] - Destination position in algebraic notation (e.g., 'e4')
  /// [promotion] - Promotion piece type for pawn promotion (e.g., 'queen')
  /// [playerId] - Player ID making the move
  Future<Map<String, dynamic>> makeMove({
    required String gameId,
    required String from,
    required String to,
    String? promotion,
    String? playerId,
  }) async {
    final body = <String, dynamic>{'from': from, 'to': to};

    if (promotion != null) {
      body['promotion'] = promotion;
    }
    if (playerId != null) {
      body['player_id'] = playerId;
    }

    logApi(
      'Sending move to backend: $from-$to (player: ${playerId ?? "none"})',
    );
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/moves'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Move failed: ${response.body}');
  }

  /// Resign from a game
  Future<void> resignGame(String gameId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/resign'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resign: ${response.statusCode}');
    }
  }

  /// Abandon a game
  Future<void> abandonGame(String gameId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/games/$gameId'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to abandon: ${response.statusCode}');
    }
  }

  /// Get list of available bots
  Future<List<Map<String, dynamic>>> getBots() async {
    final response = await http.get(Uri.parse('$baseUrl/bots'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['bots']);
    }
    throw Exception('Failed to get bots');
  }

  /// Challenge a specific bot
  Future<String> challengeBot({
    required String mode,
    required int difficulty,
    String? color, // 'white' or 'black', null for random
  }) async {
    final body = <String, dynamic>{'mode': mode, 'difficulty': difficulty};

    if (color != null) {
      body['color'] = color;
    }

    logApi('Challenging bot: mode=$mode, difficulty=$difficulty');
    final response = await http.post(
      Uri.parse('$baseUrl/bots/challenge'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['game_id'];
    }
    throw Exception('Failed to challenge bot: ${response.body}');
  }

  /// Create a bot vs bot game
  Future<Map<String, dynamic>> createBotVsBotGame({
    required String mode,
    required int whiteDifficulty,
    required int blackDifficulty,
    bool autoPlay = true,
    int moveDelay = 1000,
  }) async {
    final body = {
      'mode': mode,
      'white_difficulty': whiteDifficulty,
      'black_difficulty': blackDifficulty,
      'auto_play': autoPlay,
      'move_delay': moveDelay,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/bots/vs-bot'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create bot vs bot game: ${response.body}');
  }

  /// Pause a bot vs bot game
  Future<void> pauseGame(String gameId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/pause'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to pause game: ${response.statusCode}');
    }
  }

  /// Resume a paused bot vs bot game
  Future<void> resumeGame(String gameId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/resume'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resume game: ${response.statusCode}');
    }
  }

  /// Stop a bot vs bot game
  Future<void> stopGame(String gameId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/stop'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to stop game: ${response.statusCode}');
    }
  }

  /// Update move delay for a bot vs bot game
  Future<void> setMoveDelay(String gameId, int delayMs) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/delay'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode({'delay_ms': delayMs}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set delay: ${response.statusCode}');
    }
  }

  /// Create a bot vs bot game with custom board setup
  /// [pieces] - List of pieces with {type, color, position} format
  /// Example: [{"type": "king", "color": "white", "position": "e1"}, ...]
  Future<Map<String, dynamic>> createCustomBoardBotVsBotGame({
    required String mode,
    required List<Map<String, dynamic>> pieces,
    required String currentPlayer,
    required int whiteDifficulty,
    required int blackDifficulty,
    bool autoPlay = true,
    int moveDelay = 1000,
  }) async {
    final body = {
      'mode': mode,
      'pieces': pieces,
      'current_player': currentPlayer,
      'white_difficulty': whiteDifficulty,
      'black_difficulty': blackDifficulty,
      'auto_play': autoPlay,
      'move_delay': moveDelay,
    };

    logApi(
      'Creating custom board bot vs bot game: mode=$mode, pieces=${pieces.length}',
    );
    final response = await http.post(
      Uri.parse('$baseUrl/bots/custom-board'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create custom board game: ${response.body}');
  }

  /// Create custom board human vs bot game
  Future<Map<String, dynamic>> createCustomBoardHumanVsBot({
    required String mode,
    required List<Map<String, dynamic>> pieces,
    required String currentPlayer,
    required int botDifficulty,
    required String humanColor,
  }) async {
    final body = {
      'mode': mode,
      'pieces': pieces,
      'current_player': currentPlayer,
      'bot_difficulty': botDifficulty,
      'human_color': humanColor,
    };

    logApi(
      'Creating custom board human vs bot game: mode=$mode, pieces=${pieces.length}, human=$humanColor',
    );
    final response = await http.post(
      Uri.parse('$baseUrl/bots/custom-board-vs-bot'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception(
      'Failed to create custom board vs bot game: ${response.body}',
    );
  }

  /// Get game status (including pause state and delay)
  Future<Map<String, dynamic>> getGameStatus(String gameId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/$gameId/status'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get game status: ${response.statusCode}');
  }

  /// Reset database - clears all game records (for development/testing)
  Future<Map<String, dynamic>> resetDatabase() async {
    logApi('Resetting database...');
    final response = await http.delete(
      Uri.parse('$baseUrl/db/reset'),
      headers: {if (_authToken != null) 'Authorization': 'Bearer $_authToken'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to reset database: ${response.body}');
  }

  /// Test backend connection
  /// Test backend connection
  Future<bool> testConnection() async {
    final urls = <String>[];

    // Build list of URLs to try
    if (Platform.isAndroid) {
      // For Android emulator, try multiple possibilities
      urls.add('http://10.0.2.2:8080/health');
      // Try actual host IP as fallback (update if your IP changes)
      urls.add('http://192.168.0.26:8080/health');
    } else {
      urls.add(baseUrl.replaceAll('/api/v1', '/health'));
    }

    // Try each URL
    for (final url in urls) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          // Update baseUrl if we found a working alternative
          if (Platform.isAndroid && url.contains('192.168')) {
            manualBaseUrl = 'http://192.168.0.26:8080/api/v1';
          }
          return true;
        }
      } catch (e) {
        logError('Failed to connect to $url', e);
        continue;
      }
    }
    return false;
  }

  /// Get current user ID
  String? get userId => _userId;

  /// Check if authenticated
  bool get isAuthenticated => _authToken != null;
}
