import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

/// WebSocket service for real-time game updates
class GameWebSocket {
  // Dynamic WebSocket URL based on platform (matches ApiService logic)
  static String get wsBaseUrl {
    // For web or desktop (Windows, macOS, Linux)
    if (kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'ws://localhost:8080/api/v1/ws';
    }
    // For Android emulator
    else if (Platform.isAndroid) {
      // First try 10.0.2.2, fallback handled by connection retry
      return 'ws://10.0.2.2:8080/api/v1/ws';
    }
    // For iOS simulator
    else if (Platform.isIOS) {
      return 'ws://localhost:8080/api/v1/ws';
    }
    // Fallback
    return 'ws://localhost:8080/api/v1/ws';
  }

  WebSocketChannel? _channel;
  String? _currentGameId;
  String? _currentPlayerId;
  int _retryAttempt = 0;

  // Callbacks
  Function(Map<String, dynamic>)? onGameUpdate;
  Function(String)? onError;
  Function()? onConnected;
  Function()? onDisconnected;

  /// Get possible WebSocket URLs to try (for Android emulator fallback)
  List<String> _getWebSocketUrls(String gameId, String playerId) {
    final urls = <String>[];

    if (Platform.isAndroid) {
      // Android emulator special IP
      urls.add('ws://10.0.2.2:8080/api/v1/ws/game/$gameId?player_id=$playerId');
    } else {
      urls.add('$wsBaseUrl/game/$gameId?player_id=$playerId');
    }

    return urls;
  }

  /// Connect to a game's WebSocket with retry logic
  void connect(String gameId, String playerId) {
    if (_channel != null) {
      disconnect();
    }

    _currentGameId = gameId;
    _currentPlayerId = playerId;
    _retryAttempt = 0;
    _attemptConnection(gameId, playerId);
  }

  /// Attempt WebSocket connection with fallback URLs
  void _attemptConnection(String gameId, String playerId) {
    final urls = _getWebSocketUrls(gameId, playerId);

    if (_retryAttempt >= urls.length) {
      onError?.call('Failed to connect after ${urls.length} attempts');
      return;
    }

    final wsUrl = urls[_retryAttempt];

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            onGameUpdate?.call(data);
          } catch (e) {
            onError?.call('Failed to parse message: $e');
          }
        },
        onError: (error) {
          // Try next URL if available
          _retryAttempt++;
          if (_retryAttempt <
              _getWebSocketUrls(_currentGameId!, _currentPlayerId!).length) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _attemptConnection(_currentGameId!, _currentPlayerId!);
            });
          } else {
            onError?.call(error.toString());
            _cleanup();
          }
        },
        onDone: () {
          onDisconnected?.call();
          _cleanup();
        },
      );

      onConnected?.call();
    } catch (e) {
      onError?.call('Connection failed: $e');
      _cleanup();
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    if (_channel != null) {
      _channel?.sink.close();
      _cleanup();
    }
  }

  /// Send a message through WebSocket
  void send(Map<String, dynamic> message) {
    if (_channel != null) {
      try {
        _channel!.sink.add(json.encode(message));
      } catch (e) {
        onError?.call('Failed to send message: $e');
      }
    }
  }

  /// Check if connected
  bool get isConnected => _channel != null;

  /// Get current game ID
  String? get currentGameId => _currentGameId;

  /// Cleanup internal state
  void _cleanup() {
    _channel = null;
    _currentGameId = null;
    _currentPlayerId = null;
    _retryAttempt = 0;
  }
}
