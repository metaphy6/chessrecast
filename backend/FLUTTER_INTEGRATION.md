# Flutter Integration Guide

## Connecting ChessRecast Flutter App to Go Backend

### Overview

The backend is now ready to replace the local Dart chess engine. This guide shows how to integrate the Flutter app with the backend API.

## Architecture Changes

### Before (Current)
```
Flutter App
├── Local Engine (Dart)
├── Local AI Bots (Dart)
├── Local Game State
└── No multiplayer
```

### After (Target)
```
Flutter App
├── HTTP Client → Backend API
├── WebSocket → Real-time updates
├── Backend handles:
│   ├── Engine & validation
│   ├── AI opponents (10 levels)
│   ├── Multiplayer games
│   └── Game state
```

## Step 1: Add HTTP Package

```yaml
# pubspec.yaml
dependencies:
  http: ^1.1.0
  web_socket_channel: ^2.4.0
```

```bash
flutter pub get
```

## Step 2: Create API Service

```dart
// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  
  // For production, use your deployed URL:
  // static const String baseUrl = 'https://api.chessrecast.com/api/v1';
  
  String? _authToken;

  // Guest Login
  Future<Map<String, dynamic>> loginAsGuest() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/guest'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _authToken = data['token'];
      return data;
    }
    throw Exception('Failed to login as guest');
  }

  // Create Game (Human vs Bot)
  Future<String> createGame(String mode, int botDifficulty) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode({
        'mode': mode,
        'bot_difficulty': botDifficulty,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return data['game_id'];
    }
    throw Exception('Failed to create game');
  }

  // Get Game State
  Future<Map<String, dynamic>> getGame(String gameId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/games/$gameId'),
      headers: {
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get game');
  }

  // Make Move
  Future<Map<String, dynamic>> makeMove(
    String gameId,
    String from,
    String to, {
    String? promotion,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/moves'),
      headers: {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
      body: json.encode({
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to make move');
  }

  // Resign Game
  Future<void> resignGame(String gameId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games/$gameId/resign'),
      headers: {
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resign');
    }
  }

  // Get Available Bots
  Future<List<Map<String, dynamic>>> getBots() async {
    final response = await http.get(Uri.parse('$baseUrl/bots'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['bots']);
    }
    throw Exception('Failed to get bots');
  }
}
```

## Step 3: WebSocket for Real-time Updates

```dart
// lib/services/game_websocket.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class GameWebSocket {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onGameUpdate;
  
  void connect(String gameId, String playerId) {
    final wsUrl = 'ws://localhost:8080/api/v1/ws/game/$gameId?player_id=$playerId';
    
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    _channel!.stream.listen(
      (message) {
        final data = json.decode(message);
        onGameUpdate?.call(data);
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket closed');
      },
    );
  }
  
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
```

## Step 4: Update Game Controller

```dart
// lib/management/controller.dart modifications

import 'package:chessrecast/services/api_service.dart';
import 'package:chessrecast/services/game_websocket.dart';

class Controller extends GetxController {
  // Add API service
  final ApiService _apiService = ApiService();
  final GameWebSocket _ws = GameWebSocket();
  
  String? _currentGameId;
  
  // ... existing code ...

  // Initialize game with backend
  Future<void> initOnlineGame(ModesEnum mode, int botDifficulty) async {
    // Login as guest if not authenticated
    await _apiService.loginAsGuest();
    
    // Create game on backend
    _currentGameId = await _apiService.createGame(
      mode.toString().split('.').last,
      botDifficulty,
    );
    
    // Connect WebSocket for real-time updates
    _ws.onGameUpdate = _handleGameUpdate;
    _ws.connect(_currentGameId!, 'player_id_here');
    
    // Fetch initial game state
    final gameState = await _apiService.getGame(_currentGameId!);
    // Update local board from gameState
  }
  
  // Make move via API
  Future<bool> makeOnlineMove(Position from, Position to) async {
    if (_currentGameId == null) return false;
    
    try {
      final response = await _apiService.makeMove(
        _currentGameId!,
        from.algebraic,
        to.algebraic,
      );
      
      // Update local state
      _handleGameUpdate(response);
      return true;
    } catch (e) {
      print('Move failed: $e');
      return false;
    }
  }
  
  // Handle real-time updates from WebSocket
  void _handleGameUpdate(Map<String, dynamic> update) {
    // Parse FEN and update board
    final fen = update['board'];
    // Update UI
    update(['board']);
  }
  
  @override
  void onClose() {
    _ws.disconnect();
    super.onClose();
  }
}
```

## Step 5: Update UI to Support Online Mode

```dart
// lib/ui/home_page.dart additions

class _HomePageState extends State<HomePage> {
  bool _isOnlineMode = true; // Toggle between online/offline
  
  void _startGame(ModesEnum mode) {
    if (_isOnlineMode) {
      // Use backend
      Get.to(() => OnlineGamePage(mode: mode));
    } else {
      // Use local engine (current implementation)
      Get.to(() => GamePage(mode: mode));
    }
  }
  
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing code ...
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isOnlineMode = !_isOnlineMode;
          });
        },
        child: Icon(_isOnlineMode ? Icons.cloud : Icons.cloud_off),
        tooltip: _isOnlineMode ? 'Online Mode' : 'Offline Mode',
      ),
    );
  }
}
```

## Step 6: Bot Selection Screen

```dart
// lib/ui/bot_selection_page.dart (new file)
import 'package:flutter/material.dart';
import 'package:chessrecast/services/api_service.dart';

class BotSelectionPage extends StatefulWidget {
  final ModesEnum mode;
  
  const BotSelectionPage({required this.mode});

  @override
  State<BotSelectionPage> createState() => _BotSelectionPageState();
}

class _BotSelectionPageState extends State<BotSelectionPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _bots = [];
  
  @override
  void initState() {
    super.initState();
    _loadBots();
  }
  
  Future<void> _loadBots() async {
    final bots = await _api.getBots();
    setState(() {
      _bots = bots;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Opponent')),
      body: ListView.builder(
        itemCount: _bots.length,
        itemBuilder: (context, index) {
          final bot = _bots[index];
          return ListTile(
            leading: Icon(Icons.smart_toy),
            title: Text(bot['name']),
            subtitle: Text('Rating: ${bot['rating']}'),
            trailing: Text('Difficulty ${bot['difficulty']}'),
            onTap: () async {
              // Start game with this bot
              final controller = Get.find<Controller>();
              await controller.initOnlineGame(
                widget.mode,
                bot['difficulty'],
              );
              Get.to(() => OnlineGamePage());
            },
          );
        },
      ),
    );
  }
}
```

## Step 7: Configuration

### Development (Local Backend)
```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  static const String wsUrl = 'ws://localhost:8080/api/v1/ws';
}
```

### Production (Deployed Backend)
```dart
class ApiConfig {
  static const String baseUrl = 'https://api.chessrecast.com/api/v1';
  static const String wsUrl = 'wss://api.chessrecast.com/api/v1/ws';
}
```

### Android Network Permissions

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
  <uses-permission android:name="android.permission.INTERNET"/>
  
  <application
    android:usesCleartextTraffic="true"> <!-- For local dev only! -->
    ...
  </application>
</manifest>
```

## Step 8: Testing

### Test Backend Connection
```dart
void testBackendConnection() async {
  final api = ApiService();
  
  try {
    // Test guest login
    final guestData = await api.loginAsGuest();
    print('Guest ID: ${guestData['user_id']}');
    
    // Test creating game
    final gameId = await api.createGame('classic', 5);
    print('Game ID: $gameId');
    
    // Test getting game
    final game = await api.getGame(gameId);
    print('Game state: $game');
    
    // Test making move
    await api.makeMove(gameId, 'e2', 'e4');
    print('Move successful!');
    
  } catch (e) {
    print('Error: $e');
  }
}
```

## Migration Strategy

### Phase 1: Parallel Support (Recommended)
- Keep local engine working
- Add online mode as option
- Users choose between local/online
- Test backend stability

### Phase 2: Gradual Migration
- Default to online mode
- Fall back to local if offline
- Track usage metrics

### Phase 3: Full Backend
- Remove local engine
- All games through backend
- Enable multiplayer features

## Benefits of Backend Integration

1. **Consistent AI**: Same bot behavior on all devices
2. **Multiplayer**: Play against other players
3. **Cross-platform**: Same experience everywhere
4. **Game History**: Stored on server
5. **Analysis**: Advanced post-game analysis
6. **Matchmaking**: Find opponents
7. **Leaderboards**: Global rankings
8. **Updates**: Update AI without app update

## Troubleshooting

### Connection Failed
- Check backend is running: `docker-compose ps`
- Test health endpoint: `curl http://localhost:8080/health`
- Check Android network permissions

### WebSocket Disconnects
- Implement reconnection logic
- Store game ID and resume
- Handle connection errors gracefully

### Move Rejected
- Backend validates all moves server-side
- Check console logs for error message
- Verify move is legal in current game mode

## Performance Considerations

- **Caching**: Cache game state locally
- **Optimistic Updates**: Update UI immediately, confirm with backend
- **Debouncing**: Limit API calls during rapid interactions
- **Connection Pooling**: Reuse HTTP client

## Next Steps

1. ✅ Backend is ready
2. **Implement API service** (this guide)
3. **Test with one game mode** (start with Classic)
4. **Add WebSocket support**
5. **Implement error handling**
6. **Add offline fallback**
7. **Test multiplayer**
8. **Deploy to production**

## Example: Complete Flow

```dart
// User starts game
await _api.loginAsGuest();
final gameId = await _api.createGame('classic', 5);
_ws.connect(gameId, playerId);

// User makes move
await _api.makeMove(gameId, 'e2', 'e4');

// Bot responds (automatic via backend)
// WebSocket receives update
// UI updates

// User resigns
await _api.resignGame(gameId);
_ws.disconnect();
```

---

**Ready to connect your Flutter app to the powerful Go backend!** 🚀
