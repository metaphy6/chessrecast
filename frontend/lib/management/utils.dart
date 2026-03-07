import 'package:get/get.dart';
import '../board/utils/exporter.dart';
import '../mods/mods_enum.dart';

/// Clean helper utilities for board UI updates and conversions used by controllers
List<String> getAllSquareIds() {
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
