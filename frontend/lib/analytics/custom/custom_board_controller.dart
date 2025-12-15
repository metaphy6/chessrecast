import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../board/utils/exporter.dart';
import '../../modes/modes_enum.dart';
import '../../ui/board_theme.dart';
import '../../management/utils.dart';

/// Controller for dev board setup with optimized ID-based updates
class CustomBoardController extends GetxController {
  // Initialization flag
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Game configuration - initialized with defaults
  ModesEnum _selectedGameType = ModesEnum.classic;
  ModesEnum get selectedGameType => _selectedGameType;
  set selectedGameTypeInternal(ModesEnum value) => _selectedGameType = value;

  PieceColor _currentTurnColor = PieceColor.white;
  PieceColor get currentTurnColor => _currentTurnColor;

  List<ChessPiece> _customPieces = [];
  List<ChessPiece> get customPieces => _customPieces;

  // Bot difficulty settings - initialized with defaults
  int _whiteDifficulty = 5;
  int get whiteDifficulty => _whiteDifficulty;
  set whiteDifficulty(int value) {
    _whiteDifficulty = value.clamp(1, 10);
    update(['bot_difficulty']);
  }

  int _blackDifficulty = 5;
  int get blackDifficulty => _blackDifficulty;
  set blackDifficulty(int value) {
    _blackDifficulty = value.clamp(1, 10);
    update(['bot_difficulty']);
  }

  // Piece placement state
  PieceType? _selectedPieceType;
  PieceType? get selectedPieceType => _selectedPieceType;

  PieceColor _selectedPieceColor = PieceColor.white;
  PieceColor get selectedPieceColor => _selectedPieceColor;

  // Board theme - initialized with default
  BoardTheme _boardTheme = BoardTheme.brown;
  BoardTheme get boardTheme => _boardTheme;

  @override
  void onInit() {
    super.onInit();
    // Load standard position if pieces are empty
    if (_customPieces.isEmpty) {
      Future.microtask(() {
        loadStandardStartPosition();
      });
    }
  }

  void initialize({
    required ModesEnum gameType,
    List<ChessPiece>? pieces,
    PieceColor? currentPlayer,
  }) {
    _selectedGameType = gameType;
    _currentTurnColor = currentPlayer ?? PieceColor.white;
    _selectedPieceColor = PieceColor.white;
    _boardTheme = BoardTheme.brown;

    // Only reset difficulty if not already initialized
    if (!_isInitialized) {
      _whiteDifficulty = 5;
      _blackDifficulty = 5;
    }

    if (pieces != null && pieces.isNotEmpty) {
      _customPieces = List<ChessPiece>.from(pieces);
    } else if (!_isInitialized) {
      // PERFORMANCE: Load standard position after first frame to prevent initial jank
      _customPieces = [];
      Future.microtask(() {
        loadStandardStartPosition();
      });
    }

    _isInitialized = true;
  }

  /// Force initialize with new state - used when explicitly importing a position
  /// This will override any existing state and update all UI elements
  void forceInitialize({
    required ModesEnum gameType,
    required List<ChessPiece> pieces,
    PieceColor? currentPlayer,
    int? whiteDifficulty,
    int? blackDifficulty,
  }) {
    _selectedGameType = gameType;
    _currentTurnColor = currentPlayer ?? PieceColor.white;
    _selectedPieceColor = PieceColor.white;
    _customPieces = List<ChessPiece>.from(pieces);

    // Update difficulties without triggering individual updates
    _whiteDifficulty = (whiteDifficulty ?? 5).clamp(1, 10);
    _blackDifficulty = (blackDifficulty ?? 5).clamp(1, 10);

    _isInitialized = true;

    // Update all UI elements at once
    update([
      ...getAllSquareIds(),
      'bot_difficulty',
      'game_mode',
      'turn_selector',
    ]);
  }

  /// Force initialize from FEN notation - most reliable way to transfer positions
  /// FEN is a simple string, so no serialization issues
  void forceInitializeFromFEN({
    required ModesEnum gameType,
    required String fen,
    int? whiteDifficulty,
    int? blackDifficulty,
  }) {
    debugPrint('forceInitializeFromFEN: parsing FEN: $fen');
    try {
      // Parse FEN to get board state
      final board = ChessBoard.fromFEN(fen, gameType: gameType);
      debugPrint(
        'forceInitializeFromFEN: parsed ${board.pieces.length} pieces',
      );

      _selectedGameType = gameType;
      _currentTurnColor = board.currentPlayer;
      _selectedPieceColor = PieceColor.white;
      _customPieces = List<ChessPiece>.from(board.pieces);

      // Update difficulties without triggering individual updates
      _whiteDifficulty = (whiteDifficulty ?? 5).clamp(1, 10);
      _blackDifficulty = (blackDifficulty ?? 5).clamp(1, 10);

      _isInitialized = true;

      debugPrint(
        'forceInitializeFromFEN: updating UI with ${_customPieces.length} pieces',
      );
      // Update all UI elements at once
      update([
        ...getAllSquareIds(),
        'bot_difficulty',
        'game_mode',
        'turn_selector',
      ]);
    } catch (e) {
      debugPrint('forceInitializeFromFEN: ERROR parsing FEN: $e');
      // If FEN parsing fails, just load standard position
      loadStandardStartPosition();
    }
  }

  void loadStandardStartPosition() {
    _customPieces = List<ChessPiece>.from(ChessBoard.initial().pieces);

    // Update all squares
    update(getAllSquareIds());
  }

  void clearBoard() {
    _customPieces.clear();

    // Update all squares
    update(getAllSquareIds());
  }

  ChessPiece? getPieceAt(Position position) {
    try {
      return _customPieces.firstWhere((p) => p.position == position);
    } catch (e) {
      return null;
    }
  }

  void placePiece(Position position) {
    final squaresToUpdate = <String>[squareIdFromPosition(position)];

    if (_selectedPieceType == null) {
      // Remove piece if no piece type selected
      _customPieces.removeWhere((p) => p.position == position);
    } else {
      // Remove existing piece at this position
      _customPieces.removeWhere((p) => p.position == position);
      // Add new piece
      _customPieces.add(
        ChessPiece(
          type: _selectedPieceType!,
          color: _selectedPieceColor,
          position: position,
        ),
      );
    }

    // OPTIMIZED: Only update the affected square
    update(squaresToUpdate);
  }

  /// Place piece from selector (used by drag & drop)
  void placePieceFromSelector(
    Position position,
    PieceType type,
    PieceColor color,
  ) {
    final squaresToUpdate = <String>[squareIdFromPosition(position)];

    // Remove existing piece at this position
    _customPieces.removeWhere((p) => p.position == position);
    // Add new piece
    _customPieces.add(ChessPiece(type: type, color: color, position: position));

    // OPTIMIZED: Only update the affected square
    update(squaresToUpdate);
  }

  /// Move piece from one position to another (used by drag & drop)
  void movePieceFromTo(Position fromPosition, Position toPosition) {
    final squaresToUpdate = <String>[
      squareIdFromPosition(fromPosition),
      squareIdFromPosition(toPosition),
    ];

    // Find the piece at fromPosition
    final piece = _customPieces.firstWhere(
      (p) => p.position == fromPosition,
      orElse: () => throw Exception('No piece at $fromPosition'),
    );

    // Remove piece from its old position
    _customPieces.removeWhere((p) => p.position == fromPosition);
    // Remove any piece at the new position
    _customPieces.removeWhere((p) => p.position == toPosition);
    // Add piece to new position
    _customPieces.add(piece.copyWith(position: toPosition));

    // OPTIMIZED: Only update the two affected squares
    update(squaresToUpdate);
  }

  /// Remove piece at a specific position (used by drag to trash)
  void removePieceAt(Position position) {
    final squaresToUpdate = <String>[squareIdFromPosition(position)];

    _customPieces.removeWhere((p) => p.position == position);

    // OPTIMIZED: Only update the affected square
    update(squaresToUpdate);
  }

  void setSelectedPieceType(PieceType? type) {
    _selectedPieceType = type;
    // Update piece type (affects all piece buttons + remove button)
    update(['piece_type']);
  }

  void setSelectedPieceColor(PieceColor color) {
    _selectedPieceColor = color;
    // Update piece color (affects color chips + piece list)
    update(['piece_color']);
  }

  void setGameType(ModesEnum type) {
    _selectedGameType = type;
    // Update control panel
    update(['control_panel']);
  }

  void setCurrentTurnColor(PieceColor color) {
    _currentTurnColor = color;
    // Update control panel
    update(['control_panel']);
  }

  void setBoardTheme(BoardTheme theme) {
    _boardTheme = theme;
    // Update entire board for theme change
    update(getAllSquareIds());
  }

  /// Validates the board for the selected game type
  /// Returns a tuple of (isValid, errorMessage)
  (bool, String?) validateBoard() {
    final whiteKing = _customPieces.any(
      (p) => p.type == PieceType.king && p.color == PieceColor.white,
    );
    final blackKing = _customPieces.any(
      (p) => p.type == PieceType.king && p.color == PieceColor.black,
    );

    // Heir mode: kings can be missing (they can be captured and promoted back)
    // Succession mode: starts with no kings (must promote to get one)
    if (_selectedGameType == ModesEnum.heir ||
        _selectedGameType == ModesEnum.succession) {
      // In these modes, at least one piece must exist
      if (_customPieces.isEmpty) {
        return (false, 'Board must have at least one piece');
      }
      return (true, null);
    }

    // All other modes require both kings
    if (!whiteKing || !blackKing) {
      return (false, 'Both white and black kings must be present');
    }

    // Ensure the non-current player's king is not under attack
    // This prevents invalid board setups where the wrong player is in check
    final tempBoard = ChessBoard(
      pieces: _customPieces,
      currentPlayer: _currentTurnColor,
      gameType: _selectedGameType,
    );

    final nonCurrentPlayer = _currentTurnColor.opposite;
    final nonCurrentKing = tempBoard.getKing(nonCurrentPlayer);

    if (nonCurrentKing != null) {
      final isNonCurrentKingUnderAttack = tempBoard.isPositionUnderAttack(
        nonCurrentKing.position,
        _currentTurnColor,
      );

      if (isNonCurrentKingUnderAttack) {
        final playerName = nonCurrentPlayer == PieceColor.white
            ? 'White'
            : 'Black';
        final currentPlayerName = _currentTurnColor == PieceColor.white
            ? 'White'
            : 'Black';
        return (
          false,
          '$playerName king is under attack but it\'s $currentPlayerName\'s turn. This violates game consistency.',
        );
      }
    }

    return (true, null);
  }

  // Note: We now use getAllSquareIds() from management/utils.dart directly
}
