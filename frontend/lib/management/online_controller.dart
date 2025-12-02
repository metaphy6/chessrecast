import 'package:flutter/material.dart';
import 'package:chessrecast/debug.dart';
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
      printDebug('✅ OnlineController: WebSocket connected');
    };

    _websocket.onDisconnected = () {
      _isConnected.value = false;
      _connectionStatus.value = 'Disconnected';
      printDebug('🔌 OnlineController: WebSocket disconnected');
    };

    _websocket.onError = (error) {
      _connectionStatus.value = 'Error: $error';
      printDebug('❌ OnlineController: WebSocket error: $error');
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
        printDebug('✅ OnlineController: Logged in as ${authData['username']}');
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
      printDebug('❌ OnlineController: Setup failed: $e');
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

    printDebug(
      '🎮 OnlineController: Creating game - mode: $gameMode, bot: $botDifficulty',
    );

    final gameId = await _apiService.createGame(
      mode: gameMode,
      botDifficulty: botDifficulty,
    );

    _gameId.value = gameId;
    printDebug('✅ OnlineController: Game created: ${_gameId.value}');

    // Connect WebSocket
    _websocket.connect(_gameId.value, _playerId.value!);

    // Load initial board state
    await _syncGameState();
  }

  /// Join existing online game
  Future<void> _joinExistingGame(String gameId) async {
    _connectionStatus.value = 'Joining game...';
    _gameId.value = gameId;

    printDebug('🎮 OnlineController: Joining game: $gameId');

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
      printDebug('✅ OnlineController: Game state synced');
    } catch (e) {
      printDebug('❌ OnlineController: Failed to sync state: $e');
      _showSafeSnackbar('Sync Failed', e.toString());
    }
  }

  /// Handle WebSocket game updates
  void _handleGameUpdate(Map<String, dynamic> data) {
    printDebug('📨 OnlineController: Handling update: ${data['type']}');

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
        final playerId = gameData['player_id'] ?? 'unknown';
        printDebug('👤 Player joined: $playerId');
        _showSafeSnackbar('Player Joined', 'A player has joined the game');
        break;

      case 'player_left':
        final playerId = gameData['player_id'] ?? 'unknown';
        printDebug('👤 Player left: $playerId');
        _showSafeSnackbar('Player Left', 'A player has left the game');
        break;

      case 'pong':
        // Heartbeat response, ignore
        break;

      case 'error':
        final errorMsg = gameData['error'] ?? 'Unknown error';
        printDebug('❌ Server error: $errorMsg');
        _showSafeSnackbar('Server Error', errorMsg.toString());
        break;

      default:
        printDebug('⚠️ Unknown update type: ${data['type']}');
    }
  }

  /// Update board from backend game state
  void _updateBoardFromBackend(Map<String, dynamic> gameData) {
    try {
      // Backend can send 'fen' or 'board' field depending on the endpoint
      final fen = (gameData['fen'] ?? gameData['board']) as String?;
      if (fen == null) {
        printDebug('⚠️ OnlineController: No FEN in game data');
        return;
      }

      printDebug('♟️ OnlineController: Updating board from FEN: $fen');

      // Parse FEN and update board
      final newBoard = ChessBoard.fromFEN(fen, gameType: board.gameType);

      // Update the board state (this will trigger UI rebuild)
      updateBoardState(newBoard);

      printDebug(
        '✅ OnlineController: Board updated with ${newBoard.pieces.length} pieces',
      );
    } catch (e) {
      printDebug('❌ OnlineController: Failed to update board: $e');
    }
  }

  /// Handle move made event
  void _handleMoveMade(Map<String, dynamic> moveData) {
    printDebug(
      '♟️ OnlineController: Move made - ${moveData['from']} -> ${moveData['to']}',
    );

    // Refresh game state
    _syncGameState();
  }

  /// Handle game over event
  void _handleGameOver(Map<String, dynamic> data) {
    final result = data['result'] as String?;
    final winner = data['winner'] as String?;

    printDebug(
      '🏁 OnlineController: Game over - Result: $result, Winner: $winner',
    );

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
    printDebug('🎯 OnlineController: makeMove called');
    printDebug('🎯 OnlineController: isOnlineMode = $_isOnlineMode');
    printDebug('🎯 OnlineController: gameId = ${_gameId.value}');

    if (_isOnlineMode.value && _gameId.value.isNotEmpty) {
      // In online mode, send move to backend
      printDebug('🌐 OnlineController: Routing to backend');
      makeMoveOnline(move);
    } else {
      // Offline mode, use parent implementation
      printDebug('💻 OnlineController: Using local move (offline fallback)');
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

      printDebug(
        '📤 OnlineController: Sending move: $from -> $to (promotion: $promotion)',
      );

      // Send move to backend
      final result = await _apiService.makeMove(
        gameId: _gameId.value,
        from: from,
        to: to,
        promotion: promotion,
      );

      printDebug('✅ OnlineController: Move accepted by backend');
      printDebug('📥 OnlineController: Response: $result');

      // Update local board from backend response
      _updateBoardFromBackend(result);
    } catch (e) {
      printDebug('❌ OnlineController: Move failed: $e');
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
          // Fallback: just log if ScaffoldMessenger is not available
          printDebug('⚠️ Could not show snackbar: $title - $message');
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
      printDebug('✅ OnlineController: Resigned game');
      _showSafeSnackbar('Game Resigned', 'You have resigned the game');
    } catch (e) {
      printDebug('❌ OnlineController: Resign failed: $e');
    }
  }

  /// Get available bots
  Future<List<Map<String, dynamic>>> getAvailableBots() async {
    try {
      return await _apiService.getBots();
    } catch (e) {
      printDebug('❌ OnlineController: Failed to get bots: $e');
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

      printDebug('✅ OnlineController: Bot game created');
    } catch (e) {
      printDebug('❌ OnlineController: Bot challenge failed: $e');
      _showSafeSnackbar('Challenge Failed', e.toString());
    }
  }

  /// Pause the online game (for spectator/bot vs bot mode)
  Future<void> pauseOnlineGame() async {
    if (_gameId.value.isEmpty) return;

    try {
      await _apiService.pauseGame(_gameId.value);
      _isPaused.value = true;
      printDebug('⏸️ OnlineController: Game paused');
    } catch (e) {
      printDebug('❌ OnlineController: Pause failed: $e');
      _showSafeSnackbar('Pause Failed', e.toString());
    }
  }

  /// Resume the online game
  Future<void> resumeOnlineGame() async {
    if (_gameId.value.isEmpty) return;

    try {
      await _apiService.resumeGame(_gameId.value);
      _isPaused.value = false;
      printDebug('▶️ OnlineController: Game resumed');
    } catch (e) {
      printDebug('❌ OnlineController: Resume failed: $e');
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
