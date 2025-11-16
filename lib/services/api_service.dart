import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

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
  /// [mode] - Game mode (e.g., 'classic', 'royal_pawns')
  /// [botDifficulty] - AI difficulty level (1-10), null for PvP
  /// [opponentId] - Opponent player ID for PvP, null for bot game
  Future<String> createGame({
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
      return data['game_id'];
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
  Future<Map<String, dynamic>> makeMove({
    required String gameId,
    required String from,
    required String to,
    String? promotion,
  }) async {
    final body = <String, dynamic>{'from': from, 'to': to};

    if (promotion != null) {
      body['promotion'] = promotion;
    }

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
        print('Testing connection to: $url');
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          print('✅ Connected successfully to: $url');
          // Update baseUrl if we found a working alternative
          if (Platform.isAndroid && url.contains('192.168')) {
            manualBaseUrl = 'http://192.168.0.26:8080/api/v1';
          }
          return true;
        }
      } catch (e) {
        print('❌ Failed to connect to $url: $e');
        continue;
      }
    }

    print('❌ All connection attempts failed');
    return false;
  }

  /// Get current user ID
  String? get userId => _userId;

  /// Check if authenticated
  bool get isAuthenticated => _authToken != null;
}
