import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/utils/exporter.dart';
import '../modes/modes_enum.dart';
import '../services/api_service.dart';
import '../services/game_websocket.dart';
import 'controller.dart';
import 'utils.dart';

/// Extended controller with backend integration for online gameplay
class OnlineController extends Controller {
  final ApiService _apiService = ApiService();
  final GameWebSocket _websocket = GameWebSocket();

  // Online game state
  final RxBool _isOnlineMode = false.obs;
  final RxBool _isConnected = false.obs;
  final RxString _gameId = ''.obs;
  final Rxn<String> _playerId = Rxn<String>();
  final RxString _connectionStatus = 'Offline'.obs;
  final RxBool _isPaused = false.obs;
  final RxBool _isSpectator = false.obs;

  // Getters
  bool get isOnlineMode => _isOnlineMode.value;
  bool get isConnected => _isConnected.value;
  String? get gameId => _gameId.value.isEmpty ? null : _gameId.value;
  String? get playerId => _playerId.value;
  String get connectionStatus => _connectionStatus.value;
  bool get isPaused => _isPaused.value;
  bool get isSpectator => _isSpectator.value;

  @override
  void onInit() {
    super.onInit();

    // Check if this is an online game from route arguments
    final args = Get.arguments as Map<String, dynamic>?;
    final isOnline = args?['isOnline'] ?? false;

    if (isOnline) {
      _setupOnlineGame(args);
    }

    // Setup WebSocket callbacks
    _setupWebSocketCallbacks();
  }

  @override
  void onClose() {
    _websocket.disconnect();
    super.onClose();
  }

  /// Setup WebSocket event handlers
  void _setupWebSocketCallbacks() {
    _websocket.onConnected = () {
      _isConnected.value = true;
      _connectionStatus.value = 'Connected';
    };

    _websocket.onDisconnected = () {
      _isConnected.value = false;
      _connectionStatus.value = 'Disconnected';
    };

    _websocket.onError = (error) {
      _connectionStatus.value = 'Error: $error';
      _showSafeSnackbar('Connection Error', error);
    };

    _websocket.onGameUpdate = (data) {
      _handleGameUpdate(data);
    };
  }

  /// Setup online game from route arguments
  Future<void> _setupOnlineGame(Map<String, dynamic>? args) async {
    _isOnlineMode.value = true;
    _isSpectator.value = args?['isSpectator'] ?? false;
    _connectionStatus.value = 'Initializing...';

    try {
      // Test connection first
      final isReachable = await _apiService.testConnection();
      if (!isReachable) {
        throw Exception(
          'Backend server is not reachable at ${ApiService.baseUrl}',
        );
      }

      // Login as guest if no playerId provided
      if (args?['playerId'] == null) {
        _connectionStatus.value = 'Logging in...';
        final authData = await _apiService.loginAsGuest();
        _playerId.value = authData['user_id'];
      } else {
        _playerId.value = args!['playerId'];
      }

      // Check if joining existing game or creating new one
      if (args?['gameId'] != null) {
        await _joinExistingGame(args!['gameId']);
      } else {
        await _createNewGame(args);
      }
    } catch (e) {
      _connectionStatus.value = 'Failed: $e';
      _showSafeSnackbar('Setup Failed', e.toString());
      _isOnlineMode.value = false;
    }
  }

  /// Create new online game
  Future<void> _createNewGame(Map<String, dynamic>? args) async {
    _connectionStatus.value = 'Creating game...';

    final gameMode = args?['gameType'] is ModesEnum
        ? (args!['gameType'] as ModesEnum).toSnakeCase()
        : args?['gameType']?.toString().split('.').last ?? 'classic';
    final botDifficulty = args?['botDifficulty'] as int?;

    final gameId = await _apiService.createGame(
      mode: gameMode,
      botDifficulty: botDifficulty,
    );

    _gameId.value = gameId;

    // Connect WebSocket
    _websocket.connect(_gameId.value, _playerId.value!);

    // Load initial board state
    await _syncGameState();
  }

  /// Join existing online game
  Future<void> _joinExistingGame(String gameId) async {
    _connectionStatus.value = 'Joining game...';
    _gameId.value = gameId;

    // Connect WebSocket
    _websocket.connect(gameId, _playerId.value!);

    // Load current board state
    await _syncGameState();
  }

  /// Sync board state from backend
  Future<void> _syncGameState() async {
    if (_gameId.value.isEmpty) return;

    try {
      final gameData = await _apiService.getGame(_gameId.value);
      _updateBoardFromBackend(gameData);
    } catch (e) {
      _showSafeSnackbar('Sync Failed', e.toString());
    }
  }

  /// Handle WebSocket game updates
  void _handleGameUpdate(Map<String, dynamic> data) {
    // Backend sends flat JSON like {type, board, game_id, ...}
    // Extract nested data if present, otherwise use the data itself
    final nestedData = data['data'] as Map<String, dynamic>?;
    final gameData = nestedData ?? data;

    switch (data['type']) {
      case 'game_state':
      case 'game_update':
        // Both types use the same update logic
        // Backend sends: {type, board, game_id, state, current_turn, etc}
        _updateBoardFromBackend(gameData);
        break;

      case 'move_made':
        _handleMoveMade(gameData);
        break;

      case 'game_over':
        _handleGameOver(gameData);
        break;

      case 'player_joined':
        _showSafeSnackbar('Player Joined', 'A player has joined the game');
        break;

      case 'player_left':
        _showSafeSnackbar('Player Left', 'A player has left the game');
        break;

      case 'pong':
        // Heartbeat response, ignore
        break;

      case 'error':
        final errorMsg = gameData['error'] ?? 'Unknown error';
        _showSafeSnackbar('Server Error', errorMsg.toString());
        break;

      default:
        break;
    }
  }

  /// Update board from backend game state
  void _updateBoardFromBackend(Map<String, dynamic> gameData) {
    try {
      // Backend can send 'fen' or 'board' field depending on the endpoint
      final fen = (gameData['fen'] ?? gameData['board']) as String?;
      if (fen == null) {
        return;
      }

      // Parse FEN and update board
      final newBoard = ChessBoard.fromFEN(fen, gameType: board.gameType);

      // Update the board state (this will trigger UI rebuild)
      updateBoardState(newBoard);
    } catch (e) {
      // Error handling without debug logging
    }
  }

  /// Handle move made event
  void _handleMoveMade(Map<String, dynamic> moveData) {
    // Refresh game state
    _syncGameState();
  }

  /// Handle game over event
  void _handleGameOver(Map<String, dynamic> data) {
    final result = data['result'] as String?;
    final winner = data['winner'] as String?;

    final message = result == 'checkmate'
        ? '$winner wins by checkmate!'
        : result == 'stalemate'
        ? 'Game drawn by stalemate'
        : result == 'draw'
        ? 'Game drawn'
        : result ?? 'Game ended';

    _showSafeSnackbar('Game Over', message);

    _syncGameState();
  }

  /// Override makeMove to route to backend when in online mode
  @override
  void makeMove(ChessMove move) {
    if (_isOnlineMode.value && _gameId.value.isNotEmpty) {
      // In online mode, send move to backend
      makeMoveOnline(move);
    } else {
      // Offline mode, use parent implementation
      super.makeMove(move);
    }
  }

  /// Send move to backend and handle response
  Future<void> makeMoveOnline(ChessMove move) async {
    try {
      // Convert positions to algebraic notation
      final from = positionToAlgebraic(move.from);
      final to = positionToAlgebraic(move.to);

      // Promotion piece is already a string in ChessMove
      final promotion = move.promotionPiece;

      // Send move to backend
      final result = await _apiService.makeMove(
        gameId: _gameId.value,
        from: from,
        to: to,
        promotion: promotion,
      );

      // Update local board from backend response
      _updateBoardFromBackend(result);
    } catch (e) {
      _showSafeSnackbar('Move Failed', e.toString());
    }
  }

  /// Safe snackbar that uses ScaffoldMessenger to avoid Overlay issues
  void _showSafeSnackbar(String title, String message) {
    // Use WidgetsBinding to ensure we have a valid context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = Get.context;
      if (context != null) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $message'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          // Fallback: just ignore if ScaffoldMessenger is not available
        }
      }
    });
  }

  // positionToAlgebraic(Position) helper is provided by board_utils.dart

  /// Resign current online game
  Future<void> resignOnlineGame() async {
    if (_gameId.value.isEmpty) return;

    try {
      await _apiService.resignGame(_gameId.value);
      _showSafeSnackbar('Game Resigned', 'You have resigned the game');
    } catch (e) {
      // Error handling without debug logging
    }
  }

  /// Get available bots
  Future<List<Map<String, dynamic>>> getAvailableBots() async {
    try {
      return await _apiService.getBots();
    } catch (e) {
      return [];
    }
  }

  /// Challenge a bot
  Future<void> challengeBot(int difficulty, String gameMode) async {
    try {
      _connectionStatus.value = 'Creating bot game...';

      final gameId = await _apiService.challengeBot(
        mode: gameMode,
        difficulty: difficulty,
      );
      _gameId.value = gameId;

      // Connect WebSocket
      _websocket.connect(_gameId.value, _playerId.value!);

      // Load initial state
      await _syncGameState();
    } catch (e) {
      _showSafeSnackbar('Challenge Failed', e.toString());
    }
  }

  /// Pause the online game (for spectator/bot vs bot mode)
  Future<void> pauseOnlineGame() async {
    if (_gameId.value.isEmpty) return;

    try {
      await _apiService.pauseGame(_gameId.value);
      _isPaused.value = true;
    } catch (e) {
      _showSafeSnackbar('Pause Failed', e.toString());
    }
  }

  /// Resume the online game
  Future<void> resumeOnlineGame() async {
    if (_gameId.value.isEmpty) return;

    try {
      await _apiService.resumeGame(_gameId.value);
      _isPaused.value = false;
    } catch (e) {
      _showSafeSnackbar('Resume Failed', e.toString());
    }
  }

  /// Toggle pause/resume
  Future<void> togglePause() async {
    if (_isPaused.value) {
      await resumeOnlineGame();
    } else {
      await pauseOnlineGame();
    }
  }
}
