import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/exporter.dart';
import 'game_orchestrator.dart';

class ChessController extends GetxController {
  final ChessGameOrchestrator _gameOrchestrator = ChessGameOrchestrator();

  // Game type
  late final GameType gameType;

  // Reactive variables
  final Rx<ChessBoard> _board = ChessBoard.initial().obs;
  final RxList<Position> _validMoves = <Position>[].obs;
  final Rxn<Position> _selectedPosition = Rxn<Position>();
  final RxString _statusMessage = ''.obs;

  // Getters
  ChessBoard get board => _board.value;
  List<Position> get validMoves => _validMoves;
  Position? get selectedPosition => _selectedPosition.value;
  String get statusMessage => _statusMessage.value;

  PieceColor get currentPlayer => board.currentPlayer;
  GameStatus get gameStatus => board.gameStatus;
  bool get isGameOver => _gameOrchestrator.isGameOver(board);
  PieceColor? get winner => _gameOrchestrator.getWinner(board);

  @override
  void onInit() {
    super.onInit();

    // Get game type from route arguments
    final args = Get.arguments as Map<String, dynamic>?;
    gameType = args?['gameType'] ?? GameType.classic;

    // Initialize board with the correct game type
    _board.value = ChessBoard.initial(gameType: gameType);
    _updateStatusMessage();
  }

  /// Handles square selection on the chess board
  void onSquareSelected(Position position) {
    final piece = board.getPieceAt(position);

    // If no piece is selected
    if (_selectedPosition.value == null) {
      if (piece != null && piece.color == currentPlayer && !isGameOver) {
        _selectPiece(position);
      } else {
      }
      return;
    }

    // If same position is clicked, deselect
    if (_selectedPosition.value == position) {
      _deselectPiece();
      return;
    }

    // If another piece of the same color is clicked, select it
    if (piece != null && piece.color == currentPlayer) {
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
    _selectedPosition.value = position;
    final moves = board.getValidMovesFor(position);
    _validMoves.value = moves.map((move) => move.to).toList();
  }

  /// Deselects the current piece
  void _deselectPiece() {
    _selectedPosition.value = null;
    _validMoves.clear();
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
      if (piece.type == PieceType.pawn) {
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
        final capturedPawnPosition = Position(
          from.row, // Same rank as attacking pawn
          to.col, // Same file as target square
        );
        final capturedPawn = board.getPieceAt(capturedPawnPosition);

        if (capturedPawn != null && capturedPawn.type == PieceType.pawn) {
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
        _showMessage('Invalid move!');
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}');
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
      _showMessage('Cannot promote - King would be in check!');
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
  String _getPromotionPieceName(String piece) {
    switch (piece) {
      case 'Q':
        return 'Queen';
      case 'R':
        return 'Rook';
      case 'B':
        return 'Bishop';
      case 'N':
        return 'Knight';
      case 'K':
        return 'King';
      default:
        return 'Unknown';
    }
  }

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
      _showMessage('Invalid promotion move!');
    }
  }

  /// Makes a move and updates the board state
  void makeMove(ChessMove move) {
    try {
      final newBoard = _gameOrchestrator.executeMove(board, move);
      _board.value = newBoard;
      _updateStatusMessage();

      // Force UI update for GetBuilder widgets
      update();

      // Show move notification
      final moveNotation = move.algebraicNotation;
      _showMessage('Move: $moveNotation');
    } catch (e) {
      _showMessage('Invalid move: ${e.toString()}');
    }
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
        _statusMessage.value = 'Game is a draw.';
        // Show draw snackbar
        _showDrawSnackbar('Draw');
        break;
    }
  }

  /// Shows a winner declaration snackbar
  void _showWinnerSnackbar(String winnerColor) {
    Get.snackbar(
      '🏆 Game Over!',
      '$winnerColor Wins!',
      duration: const Duration(seconds: 5),
      snackPosition: SnackPosition.TOP,
      backgroundColor: winnerColor.toLowerCase() == 'white'
          ? Colors.blue.shade100
          : Colors.grey.shade800,
      colorText: winnerColor.toLowerCase() == 'white'
          ? Colors.blue.shade900
          : Colors.white,
      icon: const Icon(Icons.emoji_events, color: Colors.amber),
      shouldIconPulse: true,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  /// Shows a draw declaration snackbar
  void _showDrawSnackbar(String drawType) {
    Get.snackbar(
      '🤝 Game Over!',
      '$drawType - It\'s a tie!',
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.orange.shade100,
      colorText: Colors.orange.shade900,
      icon: const Icon(Icons.handshake, color: Colors.orange),
      shouldIconPulse: true,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  /// Shows a temporary message
  void _showMessage(String message) {
    // In a real app, you might want to show this in a snackbar or toast
    // For now, we'll just use Get.snackbar
    if (Get.isSnackbarOpen) return;
    Get.snackbar(
      'Chess Recast',
      message,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Resets the game to the initial state
  void resetGame() {
    _board.value = ChessBoard.initial(gameType: gameType);
    _deselectPiece();
    _updateStatusMessage();
  }

  /// Undoes the last move
  void undoLastMove() {
    if (board.moveHistory.isEmpty) return;

    // For now, we'll implement a simple undo by rebuilding the board
    // In a more sophisticated implementation, you'd maintain a history stack
    _showMessage('Undo functionality will be implemented in a future update');
  }

  /// Gets the piece at a specific position
  String? getPieceSymbol(Position position) {
    final piece = board.getPieceAt(position);
    return piece?.unicodeSymbol;
  }

  /// Gets the piece color at a specific position
  PieceColor? getPieceColor(Position position) {
    final piece = board.getPieceAt(position);
    return piece?.color;
  }

  /// Checks if a position is a valid move target
  bool isValidMoveTarget(Position position) {
    return _validMoves.contains(position);
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
    // Snare mode removed - always return false
    return false;
  }

  /// SNARE MODE: Checks if a piece at this position is entangled
  bool isPieceEntangled(Position position) {
    // Snare mode removed - always return false
    return false;
  }
}
