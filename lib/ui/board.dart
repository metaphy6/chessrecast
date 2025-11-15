import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/exporter.dart';
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
      children: const [
        Expanded(child: _BoardRow(7)), // Rank 8
        Expanded(child: _BoardRow(6)), // Rank 7
        Expanded(child: _BoardRow(5)), // Rank 6
        Expanded(child: _BoardRow(4)), // Rank 5
        Expanded(child: _BoardRow(3)), // Rank 4
        Expanded(child: _BoardRow(2)), // Rank 3
        Expanded(child: _BoardRow(1)), // Rank 2
        Expanded(child: _BoardRow(0)), // Rank 1
      ],
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
      children: [
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 0)),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 1)),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 2)),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 3)),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 4)),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 5)),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 6)),
          ),
        ),
        Expanded(
          child: RepaintBoundary(
            child: ChessSquare(position: Position(row, 7)),
          ),
        ),
      ],
    );
  }
}
