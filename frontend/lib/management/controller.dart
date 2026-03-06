import 'package:chessrecast/debug.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/utils/exporter.dart';
import '../modes/modes_enum.dart';
import '../analytics/bot/bot_manager.dart';
import '../analytics/game_analytics.dart';
import '../ui/board_theme.dart';
import '../constants.dart';
import 'orchestrator.dart';
import 'utils.dart';

class Controller extends GetxController {
  final Orchestrator _gameOrchestrator = Orchestrator();
  final BotManager botManager = Get.find<BotManager>();
  GameAnalytics? _analytics;

  // BuildContext for showing snackbars without Overlay issues
  BuildContext? _buildContext;

  // Game type
  late final ModesEnum gameType;
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

  @override
  void onInit() {
    super.onInit();

    // Get game type from route arguments
    final args = Get.arguments as Map<String, dynamic>?;
    gameType = args?['gameType'] ?? ModesEnum.classic;
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

    // Start bot move if it's bot's turn (use Future.microtask to ensure UI is ready)
    Future.microtask(() => checkBotTurn());
  }

  /// Initialize game analytics
  void _initializeAnalytics() {
    final whitePlayer = botManager.whiteBot?.name ?? 'Human';
    final blackPlayer = botManager.blackBot?.name ?? 'Human';

    _analytics = GameAnalytics(
      gameId: 'game_${DateTime.now().millisecondsSinceEpoch}',
      gameMode: gameType,
      whitePlayer: whitePlayer,
      blackPlayer: blackPlayer,
      isWhiteBot: botManager.whiteBot != null,
      isBlackBot: botManager.blackBot != null,
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
    // EXCEPTION: In Friendly Fire mode, if clicking a friendly piece, attempt capture instead
    final selectedPiece = board.getPieceAt(_selectedPosition.value!);

    // DISABLED MODE: Secret Passage king↔rook or rook↔king
    // final isSecretPassageMove =
    //     board.gameType == ModesEnum.secretPassage &&
    //     selectedPiece != null &&
    //     piece != null &&
    //     piece.color == currentPlayer &&
    //     ((selectedPiece.type == PieceType.king &&
    //             piece.type == PieceType.rook) ||
    //         (selectedPiece.type == PieceType.rook &&
    //             piece.type == PieceType.king));

    final isFriendlyFireCapture =
        board.gameType == ModesEnum.friendlyFire &&
        selectedPiece != null &&
        piece != null &&
        piece.color == currentPlayer &&
        piece.type != PieceType.king; // Can't capture own king

    if (piece != null &&
        piece.color == currentPlayer &&
        // !isSecretPassageMove && // DISABLED MODE
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
      // DISABLED MODE: Diamonds diamond zone update
      // if (board.gameType == ModesEnum.diamonds) {
      //   final prevPiece = board.getPieceAt(previousSelection);
      //   if (prevPiece?.type == PieceType.bishop) {
      //     for (final pos in _getDiamondCapturePositions(previousSelection)) {
      //       squaresToUpdate.add(squareIdFromPosition(pos));
      //     }
      //   }
      // }
    }

    squaresToUpdate.add(squareIdFromPosition(position));

    // DISABLED MODE: Diamonds diamond zone update
    // if (board.gameType == ModesEnum.diamonds) {
    //   final currentPiece = board.getPieceAt(position);
    //   if (currentPiece?.type == PieceType.bishop) {
    //     for (final pos in _getDiamondCapturePositions(position)) {
    //       squaresToUpdate.add(squareIdFromPosition(pos));
    //     }
    //   }
    // }

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
      // DISABLED MODE: Diamonds diamond zone update
      // if (board.gameType == ModesEnum.diamonds) {
      //   final prevPiece = board.getPieceAt(previousSelection);
      //   if (prevPiece?.type == PieceType.bishop) {
      //     for (final pos in _getDiamondCapturePositions(previousSelection)) {
      //       squaresToUpdate.add(squareIdFromPosition(pos));
      //     }
      //   }
      // }
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
      // Note: Mercenary mode has NO promotion
      if (piece.type == PieceType.pawn &&
          board.gameType == ModesEnum.mercenary) {
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

      // DISABLED MODE: Secret Passage king→rook swap
      // if (board.gameType == ModesEnum.secretPassage &&
      //     piece.type == PieceType.king &&
      //     capturedPiece != null &&
      //     capturedPiece.type == PieceType.rook &&
      //     capturedPiece.color == piece.color) {
      //   finalMove = ChessMove.simple(
      //     from: from,
      //     to: to,
      //     piece: piece,
      //     capturedPiece: null,
      //   );
      // }

      // DISABLED MODE: Secret Passage rook→king swap
      // if (board.gameType == ModesEnum.secretPassage &&
      //     piece.type == PieceType.rook &&
      //     capturedPiece != null &&
      //     capturedPiece.type == PieceType.king &&
      //     capturedPiece.color == piece.color) {
      //   finalMove = ChessMove.simple(
      //     from: from,
      //     to: to,
      //     piece: piece,
      //     capturedPiece: null,
      //   );
      // }

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
    // Get available promotion pieces based on game mode
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

  /// Gets available promotion pieces based on game mode and player state
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

  /// Format move in standard chess notation with piece icons
  String _formatMoveNotation(ChessMove move) {
    // Get piece icons based on color and type
    final pieceIcon = _getPieceIcon(move.piece);

    // DISABLED MODE: Special formatting for Secret Passage mode swaps
    // if (gameType == ModesEnum.secretPassage) {
    //   final targetPiece = board.getPieceAt(move.to);
    //   if (targetPiece != null && targetPiece.color == move.piece.color) {
    //     if ((move.piece.type == PieceType.king &&
    //             targetPiece.type == PieceType.rook) ||
    //         (move.piece.type == PieceType.rook &&
    //             targetPiece.type == PieceType.king)) {
    //       final movingIcon = _getPieceIcon(move.piece);
    //       final targetIcon = _getPieceIcon(targetPiece);
    //       return '$movingIcon ${move.from.algebraic} ⇄ $targetIcon ${move.to.algebraic} SECRET PASSAGE';
    //     }
    //   }
    // }

    final capture = move.capturedPiece != null ? '×' : '→';

    // Build captured piece info if applicable
    final capturedInfo = move.capturedPiece != null
        ? ' × ${_getPieceIcon(move.capturedPiece!)}'
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

  /// Makes a move and updates the board state
  void makeMove(ChessMove move) {
    // Log the move in chess notation with piece icon
    final moveNotation = _formatMoveNotation(move);
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

      // DISABLED MODE: Diamonds diamond zone updates after move
      // if (board.gameType == ModesEnum.diamonds) {
      //   if (move.piece.type == PieceType.bishop) {
      //     for (final pos in _getDiamondCapturePositions(move.from)) {
      //       squaresToUpdate.add(squareIdFromPosition(pos));
      //     }
      //     for (final pos in _getDiamondCapturePositions(move.to)) {
      //       squaresToUpdate.add(squareIdFromPosition(pos));
      //     }
      //   }
      //   if (move.capturedPiece?.type == PieceType.bishop) {
      //     for (final pos in _getDiamondCapturePositions(
      //       move.capturedPiece!.position,
      //     )) {
      //       squaresToUpdate.add(squareIdFromPosition(pos));
      //     }
      //   }
      // }

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
        if (gameType == ModesEnum.saveTheQueen &&
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
      } else {
        // Trigger bot move if it's bot's turn
        Future.microtask(() => checkBotTurn());
      }
    } catch (e) {
      _showMessage('Invalid move: ${e.toString()}');
      rethrow;
    }
  }

  /// Check if it's a bot's turn and make the move
  Future<void> checkBotTurn() async {
    // Don't proceed if game is over or auto-play is paused
    if (isGameOver) return;
    if (botManager.isPaused.value) return;

    // Check if current player is a bot
    if (!botManager.isBotTurn(currentPlayer)) return;

    final bot = botManager.getBotForPlayer(currentPlayer);
    if (bot == null) return;

    // Small delay to see moves on screen
    await Future.delayed(Duration(milliseconds: 200));

    // If auto-play is enabled, add delay
    if (botManager.isAutoPlaying.value) {
      await Future.delayed(Duration(milliseconds: botManager.moveDelay.value));

      // Check again if paused after delay
      if (botManager.isPaused.value) return;
    }

    // Get valid moves for all pieces of current player via orchestrator
    final allMoves = _gameOrchestrator.getAllValidMoves(board);

    if (allMoves.isEmpty) {
      return;
    }

    // Let the bot select a move
    final selectedMove = await bot.selectMove(board, allMoves);

    if (selectedMove != null && !isGameOver) {
      makeMove(selectedMove);
    }
  }

  /// End game analytics
  void _endGameAnalytics() {
    _analytics?.endGame(
      status: gameStatus,
      winnerColor: winner,
      reason: _getEndReason(),
    );
    _analytics?.printSummary();
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

  /// Resets the board to initial state (for live training viewer)
  void resetBoard() {
    _board.value = ChessBoard.initial(gameType: gameType);
    _deselectPiece();
    updateAllSquaresAndHistory(this);
  }

  /// Applies a move directly to the board without validation (for live training playback)
  void applyMoveDirectly(ChessMove move) {
    _board.value = _board.value.makeMove(move);
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

  /// Checks if a position is a secret passage swap target (not a capture)
  /// Used to avoid showing red highlight for friendly king/rook in Secret Passage mode
  bool isTeleportSwapTarget(Position position, ChessPiece targetPiece) {
    // DISABLED MODE: Secret Passage
    // if (board.gameType != ModesEnum.secretPassage) return false;
    // if (_selectedPosition.value == null) return false;
    // final selectedPiece = board.getPieceAt(_selectedPosition.value!);
    // if (selectedPiece == null) return false;
    // final isKingToRook =
    //     selectedPiece.type == PieceType.king &&
    //     targetPiece.type == PieceType.rook &&
    //     targetPiece.color == selectedPiece.color;
    // final isRookToKing =
    //     selectedPiece.type == PieceType.rook &&
    //     targetPiece.type == PieceType.king &&
    //     targetPiece.color == selectedPiece.color;
    // return isKingToRook || isRookToKing;
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

  /// SNARE MODE: Checks if a position is in an entangle zone
  bool isPositionInEntangleZone(Position position) {
    // DISABLED MODE: Snare
    // if (board.gameType == ModesEnum.snare) {
    //   return false;
    // }
    return false;
  }

  /// SNARE MODE: Checks if a piece at this position is entangled
  bool isPieceEntangled(Position position) {
    // DISABLED MODE: Snare
    // if (board.gameType == ModesEnum.snare) {
    //   return false;
    // }
    return false;
  }

  /// DIAMONDS MODE: Checks if a position is in the selected bishop's diamond influence zone
  bool isPositionInDiamondZone(Position position) {
    // DISABLED MODE: Diamonds
    return false;
    // if (board.gameType != ModesEnum.diamonds) {
    //   return false;
    // }
    // if (selectedPosition == null) {
    //   return false;
    // }
    // final selectedPiece = board.getPieceAt(selectedPosition!);
    // if (selectedPiece == null || selectedPiece.type != PieceType.bishop) {
    //   return false;
    // }
    // final diamondPositions = _getDiamondCapturePositions(selectedPosition!);
    // return diamondPositions.any((pos) => pos == position);
  }

  /// Helper: Gets the diamond capture pattern positions for a bishop
  /// Returns up to 8 positions forming a diamond around the bishop
  List<Position> _getDiamondCapturePositions(Position bishopPos) {
    final capturePositions = <Position>[];

    // Diamond pattern:
    // - 4 diagonal squares (1 square diagonally)
    // - 4 orthogonal squares (2 squares straight)
    final offsets = [
      // Diagonal adjacent (1 square away diagonally)
      [-1, -1], // top-left diagonal
      [-1, 1], // top-right diagonal
      [1, -1], // bottom-left diagonal
      [1, 1], // bottom-right diagonal
      // Orthogonal 2 squares away
      [-2, 0], // 2 up
      [0, 2], // 2 right
      [2, 0], // 2 down
      [0, -2], // 2 left
    ];

    for (final offset in offsets) {
      final pos = bishopPos.offset(offset[0], offset[1]);
      if (pos.isValid) {
        capturePositions.add(pos);
      }
    }

    return capturePositions;
  }
}
