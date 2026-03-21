import 'package:chessrecast/debug.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/utils/exporter.dart';
import '../mods/mods_enum.dart';
import '../analytics/game_analytics.dart';
import '../ui/board_theme.dart';
import '../constants.dart';
import 'orchestrator.dart';
import 'utils.dart';

class Controller extends GetxController {
  final Orchestrator _gameOrchestrator = Orchestrator();
  GameAnalytics? _analytics;

  // BuildContext for showing snackbars without Overlay issues
  BuildContext? _buildContext;

  // Game type
  late final ModsEnum gameType;
  late final bool isDevBoard;
  ChessBoard? _initialDevBoard; // Store the initial custom board setup
  List<ChessPiece>? _devBoardOriginalPieces; // Store original pieces from args
  PieceColor? _devBoardOriginalPlayer; // Store starting player from args
  String?
  _devBoardOriginalFEN; // Store original FEN for reliable back navigation
  int? _devBoardWhiteDifficulty; // Store difficulty for back navigation
  int? _devBoardBlackDifficulty; // Store difficulty for back navigation

  // UI preferences
  final Rx<BoardTheme> _boardTheme = BoardTheme.brown.obs;

  // Reactive variables
  final Rx<ChessBoard> _board = ChessBoard.initial().obs;
  final RxList<Position> _validMoves = <Position>[].obs;
  final Rxn<Position> _selectedPosition = Rxn<Position>();
  final RxString _statusMessage = ''.obs;

  // Move history for undo/redo
  final RxList<ChessBoard> _boardHistory = <ChessBoard>[].obs;
  final RxInt _historyIndex = (-1).obs;

  // Getters
  ChessBoard get board => _board.value;
  List<Position> get validMoves => _validMoves;
  Position? get selectedPosition => _selectedPosition.value;
  String get statusMessage => _statusMessage.value;
  bool get canUndo => _historyIndex.value > 0;
  bool get canRedo => _historyIndex.value < _boardHistory.length - 1;
  BoardTheme get boardTheme => _boardTheme.value;

  PieceColor get currentPlayer => board.currentPlayer;
  GameStatus get gameStatus => board.gameStatus;
  bool get isGameOver => _gameOrchestrator.isGameOver(board);
  PieceColor? get winner => _gameOrchestrator.getWinner(board);

  /// Returns the FEN string for each board state in history (for FEN navigation)
  List<String> get boardFenHistory =>
      _boardHistory.map((b) => b.toFEN()).toList();

  @override
  void onInit() {
    super.onInit();

    // Get game type from route arguments
    final args = Get.arguments as Map<String, dynamic>?;
    gameType = args?['gameType'] ?? ModsEnum.classic;
    isDevBoard = args?['isDevBoard'] ?? false;

    // Store difficulty settings for back navigation (used by online spectator)
    if (isDevBoard) {
      _devBoardOriginalPieces = args?['devBoardOriginalPieces'] != null
          ? List<ChessPiece>.from(
              args!['devBoardOriginalPieces'] as List<ChessPiece>,
            )
          : null;
      _devBoardOriginalPlayer =
          args?['devBoardOriginalPlayer'] as PieceColor? ?? PieceColor.white;
      _devBoardWhiteDifficulty = args?['whiteDifficulty'] as int?;
      _devBoardBlackDifficulty = args?['blackDifficulty'] as int?;

      // Create FEN from original pieces for reliable back navigation
      if (_devBoardOriginalPieces != null) {
        final tempBoard = ChessBoard(
          pieces: _devBoardOriginalPieces!,
          currentPlayer: _devBoardOriginalPlayer ?? PieceColor.white,
          gameType: gameType,
        );
        _devBoardOriginalFEN = tempBoard.toFEN();
      }
    }

    // Check if custom board setup is provided
    if (args?['customBoard'] != null &&
        args?['customBoard'] is List<ChessPiece>) {
      final customPieces = args!['customBoard'] as List<ChessPiece>;
      final customCurrentPlayer =
          args['currentPlayer'] as PieceColor? ?? PieceColor.white;

      // Store original pieces from arguments for navigation back (if not already set from isDevBoard handling)
      _devBoardOriginalPieces ??= args['devBoardOriginalPieces'] != null
          ? List<ChessPiece>.from(
              args['devBoardOriginalPieces'] as List<ChessPiece>,
            )
          : List<ChessPiece>.from(customPieces);
      _devBoardOriginalPlayer ??=
          args['devBoardOriginalPlayer'] as PieceColor? ?? customCurrentPlayer;

      // Optimize: Reduce repeated piece queries with local cache
      bool whiteKingOnStart = false;
      bool blackKingOnStart = false;
      bool whiteKingsideRookOnStart = false;
      bool whiteQueensideRookOnStart = false;
      bool blackKingsideRookOnStart = false;
      bool blackQueensideRookOnStart = false;

      // Single pass through pieces instead of 6 separate .any() calls
      for (final p in customPieces) {
        if (p.type == PieceType.king) {
          if (p.color == PieceColor.white && p.position == Position(0, 4)) {
            whiteKingOnStart = true;
          } else if (p.color == PieceColor.black &&
              p.position == Position(7, 4)) {
            blackKingOnStart = true;
          }
        } else if (p.type == PieceType.rook) {
          if (p.color == PieceColor.white) {
            if (p.position == Position(0, 7)) whiteKingsideRookOnStart = true;
            if (p.position == Position(0, 0)) whiteQueensideRookOnStart = true;
          } else if (p.color == PieceColor.black) {
            if (p.position == Position(7, 7)) blackKingsideRookOnStart = true;
            if (p.position == Position(7, 0)) blackQueensideRookOnStart = true;
          }
        }
      }

      var customBoard = ChessBoard(
        pieces: customPieces,
        gameType: gameType,
        currentPlayer: customCurrentPlayer,
        whiteCanCastleKingside: whiteKingOnStart && whiteKingsideRookOnStart,
        whiteCanCastleQueenside: whiteKingOnStart && whiteQueensideRookOnStart,
        blackCanCastleKingside: blackKingOnStart && blackKingsideRookOnStart,
        blackCanCastleQueenside: blackKingOnStart && blackQueensideRookOnStart,
        gameStatus: GameStatus.ongoing,
        moveHistory: const [],
      );

      // Evaluate the initial game status for the custom board
      customBoard = _gameOrchestrator.updateGameStatus(customBoard);

      // Add initial position to history for threefold repetition tracking
      customBoard = customBoard.copyWith(
        positionHistory: [customBoard.getPositionKey()],
      );

      _board.value = customBoard;
      _initialDevBoard = customBoard; // Store for restart functionality
    } else {
      // Initialize board with the correct game type
      _board.value = ChessBoard.initial(gameType: gameType);
    }

    // Initialize history with starting position
    _boardHistory.add(_board.value);
    _historyIndex.value = 0;

    // Initialize analytics
    _initializeAnalytics();

    _updateStatusMessage();
  }

  /// Initialize game analytics
  void _initializeAnalytics() {
    _analytics = GameAnalytics(
      gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
      gameMod: gameType,
      whitePlayer: 'Human',
      blackPlayer: 'Human',
      isWhiteBot: false,
      isBlackBot: false,
    );
  }

  /// Set the BuildContext for safe snackbar display
  void setBuildContext(BuildContext context) {
    _buildContext = context;
  }

  /// Handles square selection on the chess board
  void onSquareSelected(Position position) {
    final piece = board.getPieceAt(position);

    // If no piece is selected
    if (_selectedPosition.value == null) {
      if (piece != null && piece.color == currentPlayer && !isGameOver) {
        _selectPiece(position);
      } else {}
      return;
    }

    // If same position is clicked, deselect
    if (_selectedPosition.value == position) {
      _deselectPiece();
      return;
    }

    // If another piece of the same color is clicked, select it
    // EXCEPTION: In Friendly Fire Mod, if clicking a friendly piece, attempt capture instead
    final selectedPiece = board.getPieceAt(_selectedPosition.value!);

    final isFriendlyFireCapture =
        board.gameType == ModsEnum.friendlyFire &&
        selectedPiece != null &&
        piece != null &&
        piece.color == currentPlayer &&
        piece.type != PieceType.king; // Can't capture own king

    if (piece != null &&
        piece.color == currentPlayer &&
        !isFriendlyFireCapture) {
      _selectPiece(position);
      return;
    }

    // Try to make a move

    // Validate we have a selected position
    if (_selectedPosition.value == null) {
      return;
    }

    _attemptMove(_selectedPosition.value!, position);
  }

  /// Selects a piece and shows its valid moves
  void _selectPiece(Position position) {
    final previousSelection = _selectedPosition.value;
    final previousValidMoves = List<Position>.from(_validMoves);

    _selectedPosition.value = position;
    final moves = board.getValidMovesFor(position);

    // Fix: clear and repopulate the same RxList instead of assigning a new list
    _validMoves.clear();
    for (final move in moves) {
      _validMoves.add(move.to);
    }

    // OPTIMIZED: Batch all square updates into single update() call
    final squaresToUpdate = <String>[];

    if (previousSelection != null) {
      squaresToUpdate.add(squareIdFromPosition(previousSelection));
    }

    squaresToUpdate.add(squareIdFromPosition(position));

    for (final pos in previousValidMoves) {
      squaresToUpdate.add(squareIdFromPosition(pos));
    }
    for (final pos in _validMoves) {
      squaresToUpdate.add(squareIdFromPosition(pos));
    }

    // Single update call with all affected squares
    update(squaresToUpdate);
  }

  /// Deselects the current piece
  void _deselectPiece() {
    final previousSelection = _selectedPosition.value;
    final previousValidMoves = List<Position>.from(_validMoves);

    _selectedPosition.value = null;
    _validMoves.clear();

    // OPTIMIZED: Batch all square updates into single update() call
    final squaresToUpdate = <String>[];

    if (previousSelection != null) {
      squaresToUpdate.add(squareIdFromPosition(previousSelection));
    }

    for (final pos in previousValidMoves) {
      squaresToUpdate.add(squareIdFromPosition(pos));
    }

    // Single update call with all affected squares
    update(squaresToUpdate);
  }

  /// Attempts to make a move from the selected position to the target position
  void _attemptMove(Position from, Position to) {
    try {
      final piece = board.getPieceAt(from);
      if (piece == null) {
        return;
      }

      final capturedPiece = board.getPieceAt(to);

      // Check if this is a pawn promotion move
      // Note: Mercenary Mod has NO promotion — pawns stay as pawns on the last rank
      if (piece.type == PieceType.pawn &&
          board.gameType != ModsEnum.mercenary) {
        final lastRank = piece.color == PieceColor.white ? 7 : 0;
        if (to.row == lastRank) {
          _showPromotionDialog(from, to, piece, capturedPiece);
          return;
        }
      }

      final move = ChessMove.simple(
        from: from,
        to: to,
        piece: piece,
        capturedPiece: capturedPiece,
      );

      // Check if this should be an en passant move
      ChessMove finalMove = move;

      // If it's a pawn move and matches en passant conditions, create en passant move
      if (piece.type == PieceType.pawn &&
          board.enPassantTarget != null &&
          to == board.enPassantTarget &&
          capturedPiece == null) {
        // Find the captured pawn for en passant
        // The captured pawn is one rank behind the en passant target square
        final direction = piece.color == PieceColor.white ? -1 : 1;
        final capturedPawnPosition = Position(
          to.row + direction, // One rank behind the target square
          to.col, // Same file as target square
        );
        final capturedPawn = board.getPieceAt(capturedPawnPosition);

        if (capturedPawn != null &&
            capturedPawn.type == PieceType.pawn &&
            capturedPawn.color != piece.color) {
          finalMove = ChessMove.enPassant(
            from: from,
            to: to,
            piece: piece,
            capturedPiece: capturedPawn,
          );
        }
      }

      // Check if this should be a castling move
      if (piece.type == PieceType.king && !move.isEnPassant) {
        final kingStartCol = 4; // e-file
        final rowDiff = (to.row - from.row).abs();
        final colDiff = (to.col - from.col).abs();

        // King move of 2 squares horizontally from starting position
        if (from.col == kingStartCol && rowDiff == 0 && colDiff == 2) {
          finalMove = ChessMove.castling(from: from, to: to, piece: piece);
        }
      }

      if (_gameOrchestrator.isValidMove(board, finalMove)) {
        makeMove(finalMove);
      } else {
        // No snackbar for invalid move - causes jank
        // Visual feedback: piece just doesn't move (deselected below)
      }
    } catch (e) {
      // Only show snackbar for unexpected errors, not invalid moves
      if (AppConstants.enableDebugLogs) {
        _showMessage('Error: ${e.toString()}');
      }
    }

    _deselectPiece();
  }

  /// Shows a promotion dialog for pawn promotion
  void _showPromotionDialog(
    Position from,
    Position to,
    ChessPiece piece,
    ChessPiece? capturedPiece,
  ) {
    // Get available promotion pieces based on Game Mod
    final availablePieces = _getAvailablePromotionPieces(piece.color, to);

    // Handle case where no promotion pieces are available (King would be in check)
    if (availablePieces.isEmpty) {
      // No snackbar - causes jank. Just deselect the piece silently.
      _deselectPiece();
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Pawn Promotion'),
        content: const Text('Choose a piece to promote your pawn:'),
        actions: availablePieces.map((promotionPiece) {
          final pieceName = _getPromotionPieceName(promotionPiece);
          return TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              _executePromotionMove(
                from,
                to,
                piece,
                capturedPiece,
                promotionPiece,
              );
            },
            child: Text(pieceName),
          );
        }).toList(),
      ),
      barrierDismissible: false, // Must choose a piece
    );
  }

  /// Gets available promotion pieces based on Game Mod and player state
  List<String> _getAvailablePromotionPieces(
    PieceColor color,
    Position promotionPosition,
  ) {
    // Use the board's method which includes check validation for King promotion
    return board.getPromotionPieces(
      color,
      promotionPosition: promotionPosition,
    );
  }

  /// Gets the display name for a promotion piece
  String _getPromotionPieceName(String piece) =>
      promotionPieceNameReadable(piece);

  /// Executes a promotion move
  void _executePromotionMove(
    Position from,
    Position to,
    ChessPiece piece,
    ChessPiece? capturedPiece,
    String promotionPiece,
  ) {
    final promotionMove = ChessMove.promotion(
      from: from,
      to: to,
      piece: piece,
      capturedPiece: capturedPiece,
      promotionPiece: promotionPiece,
    );

    if (_gameOrchestrator.isValidMove(board, promotionMove)) {
      makeMove(promotionMove);
    } else {
      // No snackbar - causes jank. Invalid promotion just doesn't execute.
    }
  }

  /// Makes a move and updates the board state
  void makeMove(ChessMove move) {
    // Log the move in chess notation with piece icon
    final moveNotation = formatMoveNotation(move);
    logMove(moveNotation);

    try {
      final newBoard = _gameOrchestrator.executeMove(board, move);

      // Record move in analytics
      _analytics?.recordMove(
        '${move.from.algebraic}-${move.to.algebraic}',
        board.currentPlayer,
        isCapture: move.capturedPiece != null,
        isPromotion: move.isPromotion,
      );

      _board.value = newBoard;

      // Add to history - clear any forward history if we're not at the end
      if (_historyIndex.value < _boardHistory.length - 1) {
        _boardHistory.removeRange(
          _historyIndex.value + 1,
          _boardHistory.length,
        );
      }
      _boardHistory.add(newBoard);
      _historyIndex.value = _boardHistory.length - 1;

      _updateStatusMessage();

      // OPTIMIZED: Batch all square updates into single update() call
      final squaresToUpdate = <String>[
        squareIdFromPosition(move.from),
        squareIdFromPosition(move.to),
      ];

      // CASTLING: Also update rook squares
      if (move.isCastling) {
        final kingRow = move.from.row;
        final isKingside = move.to.col == 6; // g-file
        if (isKingside) {
          // Kingside: rook moves from h to f
          squaresToUpdate.add(
            squareIdFromPosition(Position(kingRow, 7)),
          ); // h-file
          squaresToUpdate.add(
            squareIdFromPosition(Position(kingRow, 5)),
          ); // f-file
        } else {
          // Queenside: rook moves from a to d
          squaresToUpdate.add(
            squareIdFromPosition(Position(kingRow, 0)),
          ); // a-file
          squaresToUpdate.add(
            squareIdFromPosition(Position(kingRow, 3)),
          ); // d-file
        }
      }

      if (move.capturedPiece != null) {
        squaresToUpdate.add(squareIdFromPosition(move.capturedPiece!.position));

        // SAVE THE QUEEN: If captured piece is a queen, also update prison square
        if (gameType == ModsEnum.saveTheQueen &&
            move.capturedPiece!.type == PieceType.queen) {
          // Queen might return to prison - update prison squares
          final whitePrison = Position(7, 3); // d8
          final blackPrison = Position(0, 3); // d1
          squaresToUpdate.add(squareIdFromPosition(whitePrison));
          squaresToUpdate.add(squareIdFromPosition(blackPrison));
        }
      }

      // Single batched update for all affected squares + history
      squaresToUpdate.add('history');
      update(squaresToUpdate);

      // Check if game is over and end analytics
      if (isGameOver) {
        _endGameAnalytics();
      }
    } catch (e) {
      _showMessage('Invalid move: ${e.toString()}');
      rethrow;
    }
  }

  /// Apply a board that was already computed off-thread (e.g. by the engine
  /// isolate).  Updates history, status, and triggers UI rebuilds without
  /// re-executing the move through the orchestrator.
  @protected
  void applyComputedMove(ChessBoard newBoard) {
    // Log the last move for debug output
    if (newBoard.moveHistory.isNotEmpty) {
      final lastMove = newBoard.moveHistory.last;
      logMove(formatMoveNotation(lastMove));
    }

    _board.value = newBoard;

    // History bookkeeping
    if (_historyIndex.value < _boardHistory.length - 1) {
      _boardHistory.removeRange(_historyIndex.value + 1, _boardHistory.length);
    }
    _boardHistory.add(newBoard);
    _historyIndex.value = _boardHistory.length - 1;

    _updateStatusMessage();

    // Notify all square GetBuilders by their specific IDs so pieces redraw.
    updateAllSquaresAndHistory(this);

    if (isGameOver) {
      _endGameAnalytics();
    }
  }

  /// End game analytics
  void _endGameAnalytics() {
    _analytics?.endGame(
      status: gameStatus,
      winnerColor: winner,
      reason: _getEndReason(),
    );
  }

  /// Get the end game reason
  String _getEndReason() {
    if (board.canClaimFiftyMoveRule()) {
      return '50-move rule';
    } else if (board.hasThreefoldRepetition()) {
      return 'Threefold repetition';
    } else if (gameStatus == GameStatus.checkmate) {
      return 'Checkmate';
    } else if (gameStatus == GameStatus.stalemate) {
      return 'Stalemate';
    } else if (gameStatus == GameStatus.draw) {
      return 'Draw';
    }
    return 'Unknown';
  }

  /// Updates the status message based on the current game state
  void _updateStatusMessage() {
    switch (gameStatus) {
      case GameStatus.ongoing:
        _statusMessage.value =
            '${currentPlayer.toString().toUpperCase()} to move';
        break;
      case GameStatus.check:
        _statusMessage.value =
            '${currentPlayer.toString().toUpperCase()} in check!';
        break;
      case GameStatus.checkmate:
        final winnerName = winner.toString().toUpperCase();
        _statusMessage.value = 'Checkmate! $winnerName wins!';
        // Show winner declaration snackbar
        _showWinnerSnackbar(winnerName);
        break;
      case GameStatus.stalemate:
        _statusMessage.value = 'Stalemate! Game is a draw.';
        // Show draw snackbar
        _showDrawSnackbar('Stalemate');
        break;
      case GameStatus.draw:
        // Determine draw reason
        String drawReason = 'Draw';
        if (board.canClaimFiftyMoveRule()) {
          drawReason = '50-Move Rule';
          _statusMessage.value = 'Draw by 50-move rule!';
        } else if (board.hasThreefoldRepetition()) {
          drawReason = 'Threefold Repetition';
          _statusMessage.value = 'Draw by threefold repetition!';
        } else {
          drawReason = 'Insufficient Material';
          _statusMessage.value = 'Draw by insufficient material!';
        }
        // Show draw snackbar
        _showDrawSnackbar(drawReason);
        break;
    }
    // CRITICAL: Notify GetBuilder that status message has changed
    update(['statusMessage']);
  }

  /// Shows a winner declaration snackbar
  void _showWinnerSnackbar(String winnerColor) {
    if (_buildContext == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final icon = winnerColor.toLowerCase() == 'white' ? '♔' : '♚';
        ScaffoldMessenger.of(_buildContext!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$winnerColor Wins by Checkmate!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Text('🏆', style: TextStyle(fontSize: 24)),
              ],
            ),
            backgroundColor: winnerColor.toLowerCase() == 'white'
                ? Colors.blue.shade700
                : Colors.grey.shade800,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      } catch (e) {
        // Silently ignore snackbar errors
      }
    });
  }

  /// Shows a draw declaration snackbar
  void _showDrawSnackbar(String drawType) {
    if (_buildContext == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ScaffoldMessenger.of(_buildContext!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🤝', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Game Drawn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(drawType, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      } catch (e) {
        // Silently ignore snackbar errors
      }
    });
  }

  /// Shows a temporary message
  void _showMessage(String message) {
    if (_buildContext == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Clear any existing snackbars first
        ScaffoldMessenger.of(_buildContext!).clearSnackBars();
        ScaffoldMessenger.of(_buildContext!).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      } catch (e) {
        // Silently ignore snackbar errors
      }
    });
  }

  /// Resets the game to the initial state
  void resetGame() {
    // For dev boards, reset to the initial custom setup
    if (isDevBoard && _initialDevBoard != null) {
      _board.value = _initialDevBoard!;
    } else {
      // For normal games, reset to standard initial position
      _board.value = ChessBoard.initial(gameType: gameType);
    }
    _boardHistory.clear();
    _boardHistory.add(_board.value);
    _historyIndex.value = 0;
    _deselectPiece();
    _updateStatusMessage();

    // Update all 64 squares to reflect the reset board state
    updateAllSquaresAndHistory(this);
  }

  /// Undoes the last move
  void undoLastMove() {
    if (!canUndo) {
      return;
    }

    _historyIndex.value--;
    _board.value = _boardHistory[_historyIndex.value];
    _deselectPiece();
    _updateStatusMessage();

    // Update all 64 squares to reflect the undo
    updateAllSquaresAndHistory(this);
  }

  /// Redoes the last undone move
  void redoMove() {
    if (!canRedo) {
      return;
    }

    _historyIndex.value++;
    _board.value = _boardHistory[_historyIndex.value];
    _deselectPiece();
    _updateStatusMessage();

    // Update all 64 squares to reflect the redo
    updateAllSquaresAndHistory(this);
  }

  /// Navigates back to dev board setup or home
  void navigateBack() {
    if (isDevBoard &&
        (_devBoardOriginalFEN != null || _devBoardOriginalPieces != null)) {
      // Navigate back to dev board setup with the original configuration
      // Prefer FEN (simple string) over pieces list for reliability
      Get.offAllNamed(
        '/custom-board',
        arguments: {
          'gameType': gameType,
          'fen': _devBoardOriginalFEN, // FEN takes priority if available
          'pieces': _devBoardOriginalPieces, // Fallback
          'currentPlayer': _devBoardOriginalPlayer,
          'whiteDifficulty': _devBoardWhiteDifficulty,
          'blackDifficulty': _devBoardBlackDifficulty,
          'fenHistory': boardFenHistory,
        },
      );
    } else {
      // Navigate to home for normal games
      Get.offAllNamed('/');
    }
  }

  /// Gets the piece at a specific position (returns ChessPiece, not symbol)
  ChessPiece? getPieceAt(Position position) {
    return board.getPieceAt(position);
  }

  /// Gets the piece color at a specific position
  PieceColor? getPieceColor(Position position) {
    final piece = board.getPieceAt(position);
    return piece?.color;
  }

  /// Change the board theme
  void setBoardTheme(BoardTheme theme) {
    _boardTheme.value = theme;
    update(['boardTheme']); // Granular update
  }

  /// Update the board state directly (for online mode)
  /// Adds to history so undo/redo works for online games
  @protected
  void updateBoardState(ChessBoard newBoard) {
    // CRITICAL: Evaluate game status to trigger logging and check/checkmate detection
    // This ensures online games log events just like local games
    final evaluatedBoard = _gameOrchestrator.updateGameStatus(newBoard);
    _board.value = evaluatedBoard;

    // Add to history for undo/redo in online games
    // Clear any forward history if we're not at the end
    if (_historyIndex.value < _boardHistory.length - 1) {
      _boardHistory.removeRange(_historyIndex.value + 1, _boardHistory.length);
    }
    _boardHistory.add(evaluatedBoard);
    _historyIndex.value = _boardHistory.length - 1;

    // Update all squares and history UI
    updateAllSquaresAndHistory(this);
  }

  /// Checks if a position is a valid move target (optimized for hot path)
  bool isValidMoveTarget(Position position) {
    // Direct iteration is faster than contains() for small lists
    for (final pos in _validMoves) {
      if (pos == position) return true;
    }
    return false;
  }

  /// Checks if a position is the selected position
  bool isSelectedPosition(Position position) {
    return _selectedPosition.value == position;
  }

  /// Gets all pieces for a specific color (useful for captured pieces display)
  List<String> getCapturedPieces(PieceColor color) {
    // This would track captured pieces in a real implementation
    // For now, return empty list
    return [];
  }
}
