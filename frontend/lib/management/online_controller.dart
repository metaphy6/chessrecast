import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/utils/exporter.dart';
import '../debug.dart';
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

  // Move validation toggle - set to false if performance issues occur
  static const bool enableMoveValidation = true;
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

    final gameData = await _apiService.createGame(
      mode: gameMode,
      botDifficulty: botDifficulty,
    );

    _gameId.value = gameData['game_id'];
    // Store the player_id returned by backend (if present)
    if (gameData['player_id'] != null) {
      _playerId.value = gameData['player_id'];
    }

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
      print('🔄 DEBUG: Syncing game state for game: ${_gameId.value}');
      final gameData = await _apiService.getGame(_gameId.value);
      print('📥 DEBUG: Received game data from API: $gameData');
      _updateBoardFromBackend(gameData);
    } catch (e) {
      print('❌ DEBUG: Error syncing game state: $e');
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
      print('🔍 DEBUG: _updateBoardFromBackend called with data: $gameData');

      // Backend can send 'fen' or 'board' field depending on the endpoint
      final fen = (gameData['fen'] ?? gameData['board']) as String?;
      print('🔍 DEBUG: FEN extracted: $fen');

      if (fen == null) {
        print('⚠️ DEBUG: FEN is null, returning early');
        return;
      }

      // Parse FEN and update board
      final newBoard = ChessBoard.fromFEN(fen, gameType: board.gameType);
      print(
        '✅ DEBUG: Board parsed successfully, pieces count: ${newBoard.pieces.length}',
      );

      // Detect and log the move that was made (especially for bot moves)
      _logMoveFromBoardChange(board, newBoard);

      // Update the board state (this will trigger UI rebuild)
      updateBoardState(newBoard);
    } catch (e) {
      print('❌ DEBUG: Error in _updateBoardFromBackend: $e');
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
      // Log the move in chess notation with piece icon
      final moveNotation = _formatMoveNotation(move);
      logMove(moveNotation);

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
        playerId: _playerId.value,
      );

      // Double validation: Compare backend response with frontend game rules
      // This ensures both backend and frontend agree on move legality
      // Can be disabled if performance issues occur (set enableMoveValidation = false)
      if (enableMoveValidation && !_validateBackendMove(result, move)) {
        _showSafeSnackbar(
          'Validation Error',
          'Backend and frontend rules disagree on move legality. Please refresh the game.',
        );
        // Re-sync game state to recover
        await _syncGameState();
        return;
      }

      // Update local board from backend response
      _updateBoardFromBackend(result);
    } catch (e) {
      _showSafeSnackbar('Move Failed', e.toString());
    }
  }

  /// Validate that backend move response matches frontend game rules
  /// Returns true if validation passes, false if there's a discrepancy
  bool _validateBackendMove(
    Map<String, dynamic> backendResult,
    ChessMove frontendMove,
  ) {
    try {
      // Extract FEN from backend response
      final backendFen =
          (backendResult['fen'] ?? backendResult['board']) as String?;
      if (backendFen == null) {
        // No FEN in response - skip validation (backend might send different format)
        return true;
      }

      // Simulate the move on frontend board
      final testBoard = board.makeMove(frontendMove);
      final frontendFen = testBoard.toFEN();

      // Compare FEN strings (they should match if both backend and frontend agree)
      if (backendFen == frontendFen) {
        return true;
      }

      // FEN mismatch detected - log for debugging
      debugPrint('⚠️ VALIDATION ERROR: Backend/Frontend FEN mismatch');
      debugPrint('Backend FEN:  $backendFen');
      debugPrint('Frontend FEN: $frontendFen');
      debugPrint(
        'Move: ${positionToAlgebraic(frontendMove.from)}-${positionToAlgebraic(frontendMove.to)}',
      );

      return false;
    } catch (e) {
      // If validation fails due to exception, log and allow move
      // (don't block gameplay due to validation issues)
      debugPrint('⚠️ Move validation error: $e');
      return true; // Allow move to proceed
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

  /// Format move notation (replicated from parent private method)
  String _formatMoveNotation(ChessMove move) {
    final pieceIcon = _getPieceIcon(move.piece);

    // Special formatting for Secret Passage mode swaps
    if (gameType == ModesEnum.secretPassage) {
      final targetPiece = board.getPieceAt(move.to);
      if (targetPiece != null && targetPiece.color == move.piece.color) {
        if ((move.piece.type == PieceType.king &&
                targetPiece.type == PieceType.rook) ||
            (move.piece.type == PieceType.rook &&
                targetPiece.type == PieceType.king)) {
          final movingIcon = _getPieceIcon(move.piece);
          final targetIcon = _getPieceIcon(targetPiece);
          return '$movingIcon ${move.from.algebraic} ⇄ $targetIcon ${move.to.algebraic} SECRET PASSAGE';
        }
      }
    }

    final capture = move.capturedPiece != null ? '×' : '→';
    final capturedInfo = move.capturedPiece != null
        ? ' [captured ${_getPieceIcon(move.capturedPiece!)}]'
        : '';

    return '$pieceIcon ${move.from.algebraic}$capture${move.to.algebraic}$capturedInfo';
  }

  /// Get emoji icon for a chess piece
  String _getPieceIcon(ChessPiece piece) {
    const whiteIcons = {
      'pawn': '♙',
      'rook': '♖',
      'knight': '♘',
      'bishop': '♗',
      'queen': '♕',
      'king': '♔',
    };
    const blackIcons = {
      'pawn': '♟',
      'rook': '♜',
      'knight': '♞',
      'bishop': '♝',
      'queen': '♛',
      'king': '♚',
    };

    final icons = piece.color == PieceColor.white ? whiteIcons : blackIcons;
    return icons[piece.type.name] ?? '?';
  }

  /// Detect and log move from board state change (for bot moves received via backend)
  void _logMoveFromBoardChange(ChessBoard oldBoard, ChessBoard newBoard) {
    // Compare piece positions to detect the move
    // This is needed for bot moves that come through WebSocket/backend updates
    try {
      // Find pieces that moved or were captured
      ChessPiece? movedPiece;
      Position? fromPos;
      Position? toPos;
      ChessPiece? capturedPiece;

      // Check for pieces that disappeared (moved or captured)
      for (final oldPiece in oldBoard.pieces) {
        final newPieceAtSamePos = newBoard.pieces.firstWhere(
          (p) => p.position == oldPiece.position,
          orElse: () => ChessPiece(
            type: PieceType.pawn,
            color: PieceColor.white,
            position: Position(-1, -1),
          ),
        );

        if (newPieceAtSamePos.position.row == -1) {
          // Piece disappeared from this position
          fromPos = oldPiece.position;
          movedPiece = oldPiece;
        }
      }

      // Check for pieces that appeared (moved to)
      for (final newPiece in newBoard.pieces) {
        final oldPieceAtSamePos = oldBoard.pieces.firstWhere(
          (p) => p.position == newPiece.position,
          orElse: () => ChessPiece(
            type: PieceType.pawn,
            color: PieceColor.white,
            position: Position(-1, -1),
          ),
        );

        if (oldPieceAtSamePos.position.row == -1) {
          // New piece appeared at this position
          toPos = newPiece.position;
          // Check if something was captured
          for (final oldPiece in oldBoard.pieces) {
            if (oldPiece.position == toPos &&
                oldPiece.color != newPiece.color) {
              capturedPiece = oldPiece;
            }
          }
        }
      }

      // If we detected a move, log it
      if (movedPiece != null && fromPos != null && toPos != null) {
        final move = ChessMove.simple(
          from: fromPos,
          to: toPos,
          piece: movedPiece,
          capturedPiece: capturedPiece,
        );
        // Format the move with piece icon
        final notation = _formatMoveNotation(move);
        logMove(notation);
      }
    } catch (e) {
      // If move detection fails, just skip logging (don't block gameplay)
      debugPrint('Failed to detect move for logging: $e');
    }
  }
}
