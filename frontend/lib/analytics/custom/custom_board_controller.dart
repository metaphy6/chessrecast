import 'package:get/get.dart';
import '../../board/utils/exporter.dart';
import '../../modes/modes_enum.dart';
import '../../ui/board_theme.dart';
import '../../management/utils.dart';

/// Controller for dev board setup with optimized ID-based updates
class CustomBoardController extends GetxController {
  // Game configuration
  late ModesEnum _selectedGameType;
  ModesEnum get selectedGameType => _selectedGameType;

  late PieceColor _currentTurnColor;
  PieceColor get currentTurnColor => _currentTurnColor;

  late List<ChessPiece> _customPieces;
  List<ChessPiece> get customPieces => _customPieces;

  // Piece placement state
  PieceType? _selectedPieceType;
  PieceType? get selectedPieceType => _selectedPieceType;

  late PieceColor _selectedPieceColor;
  PieceColor get selectedPieceColor => _selectedPieceColor;

  // Board theme
  late BoardTheme _boardTheme;
  BoardTheme get boardTheme => _boardTheme;

  void initialize({
    required ModesEnum gameType,
    List<ChessPiece>? pieces,
    PieceColor? currentPlayer,
  }) {
    _selectedGameType = gameType;
    _currentTurnColor = currentPlayer ?? PieceColor.white;
    _selectedPieceColor = PieceColor.white;
    _boardTheme = BoardTheme.brown;

    if (pieces != null && pieces.isNotEmpty) {
      _customPieces = List<ChessPiece>.from(pieces);
    } else {
      // PERFORMANCE: Load standard position after first frame to prevent initial jank
      _customPieces = [];
      Future.microtask(() {
        loadStandardStartPosition();
      });
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

  bool validateBoard() {
    final whiteKing = _customPieces.any(
      (p) => p.type == PieceType.king && p.color == PieceColor.white,
    );
    final blackKing = _customPieces.any(
      (p) => p.type == PieceType.king && p.color == PieceColor.black,
    );

    return whiteKing && blackKing;
  }

  // Note: We now use getAllSquareIds() from management/utils.dart directly
}
