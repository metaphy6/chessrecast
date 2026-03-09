import 'dart:convert';
import 'dart:io';
import 'dart:async';
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
  StreamSubscription? _subscription;
  String? _currentGameId;
  String? _currentPlayerId;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 10;
  bool _userDisconnected = false;

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
    _userDisconnected = false;
    if (_channel != null) {
      disconnect();
    }

    _currentGameId = gameId;
    _currentPlayerId = playerId;
    _reconnectAttempt = 0;
    _attemptConnection(gameId, playerId);
  }

  /// Attempt WebSocket connection with handshake await
  void _attemptConnection(String gameId, String playerId) {
    final urls = _getWebSocketUrls(gameId, playerId);
    if (urls.isEmpty) {
      onError?.call('No WebSocket URLs available');
      return;
    }

    final wsUrl = urls[0]; // use primary URL (platform-dependent)

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.ready.then((_) {
        _reconnectAttempt = 0;

        _subscription = _channel!.stream.listen(
          (message) {
            try {
              final data = json.decode(message);
              onGameUpdate?.call(data);
            } catch (e) {
              onError?.call('Failed to parse message: $e');
            }
          },
          onError: (error) {
            _handleConnectionLost(error.toString());
          },
          onDone: () {
            _handleConnectionLost('Server closed connection');
          },
        );

        onConnected?.call();
      }).catchError((error) {
        _handleConnectionLost('Handshake failed: $error');
      });
    } catch (e) {
      _handleConnectionLost('Connection failed: $e');
    }
  }

  /// Handle unexpected connection loss — cleanup and schedule reconnect
  void _handleConnectionLost(String reason) {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    onDisconnected?.call();

    if (!_userDisconnected &&
        _currentGameId != null &&
        _currentPlayerId != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempt >= _maxReconnectAttempts) {
      onError?.call(
          'Failed to reconnect after $_maxReconnectAttempts attempts');
      _cleanup();
      return;
    }

    final delaySec = (_reconnectAttempt < 4)
        ? 1 + _reconnectAttempt       // 1, 2, 3, 4
        : (4 * (1 << (_reconnectAttempt - 4))).clamp(4, 30);
    _reconnectAttempt++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), () {
      if (!_userDisconnected &&
          _currentGameId != null &&
          _currentPlayerId != null) {
        _attemptConnection(_currentGameId!, _currentPlayerId!);
      }
    });
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _userDisconnected = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _cleanup();
  }

  /// Send a message through WebSocket
  void send(Map<String, dynamic> message) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(json.encode(message));
    } catch (e) {
      onError?.call('Failed to send message: $e');
    }
  }

  /// Check if connected
  bool get isConnected => _channel != null;

  /// Get current game ID
  String? get currentGameId => _currentGameId;

  /// Cleanup internal state
  void _cleanup() {
    _channel = null;
    _subscription = null;
    _currentGameId = null;
    _currentPlayerId = null;
    _reconnectAttempt = 0;
  }
}
