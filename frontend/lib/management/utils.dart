import 'package:get/get.dart';
import '../board/utils/exporter.dart';
import '../mods/enums.dart';

/// Cached square IDs — computed once since the board is always 8x8
final List<String> _allSquareIds = _buildSquareIds();

List<String> _buildSquareIds() {
  final squares = <String>[];
  const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  const ranks = ['1', '2', '3', '4', '5', '6', '7', '8'];
  for (final f in files) {
    for (final r in ranks) {
      squares.add('square_$f$r');
    }
  }
  return squares;
}

List<String> getAllSquareIds() => _allSquareIds;

List<String> squareIdsFromPositions(Iterable<Position> positions) {
  return positions.map((p) => squareIdFromPosition(p)).toList();
}

String squareIdFromPosition(Position position) =>
    'square_${position.algebraic}';

/// Safely get algebraic notation for a position (wrapper around Position.algebraic)
String positionToAlgebraic(Position pos) => pos.algebraic;

/// Map promotion piece short code to human readable name
String promotionPieceNameReadable(String piece) {
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

/// Update all board squares plus history entry
void updateAllSquaresAndHistory(GetxController controller) {
  final ids = [...getAllSquareIds(), 'history'];
  controller.update(ids);
}

/// Update a list of specific square IDs
void updateSquareIds(GetxController controller, List<String> ids) {
  controller.update(ids);
}

/// Update the previously-selected and newly-selected mode ids in Options UI
void updateModeSelection(
  GetxController controller,
  ModsEnum previous,
  ModsEnum current,
) {
  controller.update(['mode_${previous.name}', 'mode_${current.name}']);
}

// ─── Shared move notation helpers ────────────────────────────────────────────

/// Format move in standard chess notation with piece icons
String formatMoveNotation(ChessMove move) {
  final pieceIcon = getPieceIcon(move.piece);
  final capture = move.capturedPiece != null ? '×' : '→';
  final capturedInfo = move.capturedPiece != null
      ? ' × ${getPieceIcon(move.capturedPiece!)}'
      : '';
  return '$pieceIcon ${move.from.algebraic}$capture${move.to.algebraic}$capturedInfo';
}

/// Get emoji icon for a chess piece
String getPieceIcon(ChessPiece piece) {
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
