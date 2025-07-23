import 'package:get/get.dart';
import '../../domain/entities/chess_board.dart';
import '../../domain/entities/chess_move.dart';
import '../../domain/entities/position.dart';
import '../../domain/services/chess_game_service.dart';
import '../../domain/enums/piece_color.dart';
import '../../domain/enums/piece_type.dart';
import '../../domain/enums/game_status.dart';

class ChessController extends GetxController {
  final ChessGameService _gameService = ChessGameService();

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
  bool get isGameOver => _gameService.isGameOver(board);
  PieceColor? get winner => _gameService.getWinner(board);

  @override
  void onInit() {
    super.onInit();
    print('DEBUG: ChessController.onInit() called');
    print('DEBUG: Initial board has ${board.pieces.length} pieces');
    _updateStatusMessage();
  }

  /// Handles square selection on the chess board
  void onSquareSelected(Position position) {
    print('🔥 onSquareSelected called for ${position.algebraic}');
    final piece = board.getPieceAt(position);
    print(
      '🔍 Piece at ${position.algebraic}: ${piece?.type.name ?? 'EMPTY'} ${piece?.color.name ?? 'N/A'}',
    );
    print('🎮 Current player: ${currentPlayer.name}, Game over: $isGameOver');

    // If no piece is selected
    if (_selectedPosition.value == null) {
      if (piece != null && piece.color == currentPlayer && !isGameOver) {
        print('✅ Selecting piece at ${position.algebraic}');
        _selectPiece(position);
      } else {
        print(
          '❌ Cannot select - piece: ${piece?.type.name ?? 'none'}, currentPlayer: ${currentPlayer.name}, gameOver: $isGameOver',
        );
      }
      return;
    }

    // If same position is clicked, deselect
    if (_selectedPosition.value == position) {
      print('🔄 Deselecting piece at ${position.algebraic}');
      _deselectPiece();
      return;
    }

    // If another piece of the same color is clicked, select it
    if (piece != null && piece.color == currentPlayer) {
      print('🔄 Selecting different piece at ${position.algebraic}');
      _selectPiece(position);
      return;
    }

    // Try to make a move
    print(
      '🎯 Attempting move from ${_selectedPosition.value!.algebraic} to ${position.algebraic}',
    );
    print(
      '🔧 About to call _attemptMove with positions: ${_selectedPosition.value?.algebraic} → ${position.algebraic}',
    );

    // Validate we have a selected position
    if (_selectedPosition.value == null) {
      print('💥 ERROR: _selectedPosition.value is null!');
      return;
    }

    _attemptMove(_selectedPosition.value!, position);
    print('🏁 _attemptMove call completed');
  }

  /// Selects a piece and shows its valid moves
  void _selectPiece(Position position) {
    print('DEBUG: _selectPiece called for ${position.algebraic}');
    _selectedPosition.value = position;
    final moves = board.getValidMovesFor(position);
    print(
      'DEBUG: Found ${moves.length} valid moves for piece at ${position.algebraic}',
    );
    _validMoves.value = moves.map((move) => move.to).toList();
  }

  /// Deselects the current piece
  void _deselectPiece() {
    _selectedPosition.value = null;
    _validMoves.clear();
  }

  /// Attempts to make a move from the selected position to the target position
  void _attemptMove(Position from, Position to) {
    print('🚀 _attemptMove: ${from.algebraic} → ${to.algebraic}');
    try {
      final piece = board.getPieceAt(from);
      print(
        '📋 Piece at source: ${piece?.type.name ?? 'NONE'} ${piece?.color.name ?? 'N/A'}',
      );
      if (piece == null) {
        print('❌ No piece at source position');
        return;
      }

      final capturedPiece = board.getPieceAt(to);
      print(
        '🎯 Target piece: ${capturedPiece?.type.name ?? 'EMPTY'} ${capturedPiece?.color.name ?? 'N/A'}',
      );

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
          print(
            '🎯 Converting to en passant move: ${from.algebraic} → ${to.algebraic}, capturing ${capturedPawn.position.algebraic}',
          );
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
          print(
            '🏰 Converting to castling move: ${from.algebraic} → ${to.algebraic}',
          );
          finalMove = ChessMove.castling(from: from, to: to, piece: piece);
        }
      }

      print('♟️ Created move: ${finalMove.algebraicNotation}');

      if (_gameService.isValidMove(board, finalMove)) {
        print('✅ Move is valid, executing...');
        makeMove(finalMove);
      } else {
        print('❌ Move validation failed');
        _showMessage('Invalid move!');
      }
    } catch (e) {
      print('💥 Exception in _attemptMove: ${e.toString()}');
      _showMessage('Error: ${e.toString()}');
    }

    _deselectPiece();
  }

  /// Makes a move and updates the board state
  void makeMove(ChessMove move) {
    print('🎮 makeMove called: ${move.algebraicNotation}');
    try {
      final newBoard = _gameService.executeMove(board, move);
      print('🏁 Move executed successfully');
      print('📊 Board updated, triggering UI refresh');
      _board.value = newBoard;
      _updateStatusMessage();

      // Force UI update for GetBuilder widgets
      update();
      print('🔄 UI update() called');

      // Show move notification
      final moveNotation = move.algebraicNotation;
      _showMessage('Move: $moveNotation');
      print('✨ Move completed: $moveNotation');
    } catch (e) {
      print('💥 Exception in makeMove: ${e.toString()}');
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
        break;
      case GameStatus.stalemate:
        _statusMessage.value = 'Stalemate! Game is a draw.';
        break;
      case GameStatus.draw:
        _statusMessage.value = 'Game is a draw.';
        break;
    }
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
    _board.value = ChessBoard.initial();
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
}
