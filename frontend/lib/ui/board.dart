import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/utils/exporter.dart';
import '../management/controller.dart';
import 'square.dart';

class ChessBoardWidget extends StatelessWidget {
  const ChessBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple.shade800, width: 4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: GetBuilder<Controller>(
            id: 'boardTheme',
            builder: (controller) {
              final theme = controller.boardTheme;
              return Stack(
                children: [
                  // Board background image - cached
                  Positioned.fill(child: theme.getImage(fit: BoxFit.cover)),
                  // Grid of squares - only rebuild affected squares
                  const _BoardGrid(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Separate widget for board grid to prevent unnecessary rebuilds
class _BoardGrid extends StatelessWidget {
  const _BoardGrid();

  @override
  Widget build(BuildContext context) {
    // Pre-build all square widgets with RepaintBoundary to prevent cascading repaints
    return Column(
      children: List.generate(
        8,
        (index) => Expanded(child: _BoardRow(7 - index)),
      ),
    );
  }
}

/// Const row widget for each rank - prevents unnecessary rebuilds
class _BoardRow extends StatelessWidget {
  final int row;

  const _BoardRow(this.row);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        8,
        (col) => Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, col)),
          ),
        ),
      ),
    );
  }
}
