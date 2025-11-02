import 'package:flutter/material.dart';
import '../board/exporter.dart';
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
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.purple.shade600, width: 2),
          ),
          child: Column(
            children: List.generate(8, (row) {
              // Display from rank 8 to rank 1 (top to bottom)
              final boardRow = 7 - row;
              return Expanded(
                child: Row(
                  children: List.generate(8, (col) {
                    final position = Position(boardRow, col);
                    return Expanded(child: ChessSquare(position: position));
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
