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

  // Getters
  bool get isOnlineMode => _isOnlineMode.value;
  bool get isConnected => _isConnected.value;
  String? get gameId => _gameId.value.isEmpty ? null : _gameId.value;
  String? get playerId => _playerId.value;
  String get connectionStatus => _connectionStatus.value;

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
      Get.snackbar(
        'Connection Error',
        error,
        snackPosition: SnackPosition.BOTTOM,
      );
    };

    _websocket.onGameUpdate = (data) {
      _handleGameUpdate(data);
    };
  }

  /// Setup online game from route arguments
  Future<void> _setupOnlineGame(Map<String, dynamic>? args) async {
    _isOnlineMode.value = true;
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
      Get.snackbar(
        'Setup Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
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
      Get.snackbar(
        'Sync Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Handle WebSocket game updates
  void _handleGameUpdate(Map<String, dynamic> data) {
    printDebug('📨 OnlineController: Handling update: ${data['type']}');

    switch (data['type']) {
      case 'game_state':
        _updateBoardFromBackend(data['data']);
        break;

      case 'game_update':
        // Handle generic game update (sent by bot vs bot games)
        // Backend sends: {type, board, game_id, state, etc}
        // Need to pass the whole update as game data
        _updateBoardFromBackend(data);
        break;

      case 'move_made':
        _handleMoveMade(data['data']);
        break;

      case 'game_over':
        _handleGameOver(data['data']);
        break;

      case 'player_joined':
        printDebug('👤 Player joined: ${data['data']['player_id']}');
        Get.snackbar(
          'Player Joined',
          'A player has joined the game',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
        break;

      case 'player_left':
        printDebug('👤 Player left: ${data['data']['player_id']}');
        Get.snackbar(
          'Player Left',
          'A player has left the game',
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 2),
        );
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

    Get.snackbar(
      'Game Over',
      result == 'checkmate'
          ? '$winner wins by checkmate!'
          : result == 'stalemate'
          ? 'Game drawn by stalemate'
          : result == 'draw'
          ? 'Game drawn'
          : result ?? 'Game ended',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
    );

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
      Get.snackbar(
        'Move Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // positionToAlgebraic(Position) helper is provided by board_utils.dart

  /// Resign current online game
  Future<void> resignOnlineGame() async {
    if (_gameId.value.isEmpty) return;

    try {
      await _apiService.resignGame(_gameId.value);
      printDebug('✅ OnlineController: Resigned game');

      Get.snackbar(
        'Game Resigned',
        'You have resigned the game',
        snackPosition: SnackPosition.TOP,
      );
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
      Get.snackbar(
        'Challenge Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
