import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/exporter.dart';
import '../management/controller.dart';
import 'square.dart';

class ChessBoardWidget extends StatelessWidget {
  const ChessBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<Controller>();

    return Obx(() {
      final theme = controller.boardTheme;

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
            child: Stack(
              children: [
                // Board background image
                Positioned.fill(child: theme.getImage(fit: BoxFit.cover)),
                // Grid of squares (transparent, only for interaction and overlays)
                Column(
                  children: List.generate(8, (row) {
                    // Display from rank 8 to rank 1 (top to bottom)
                    final boardRow = 7 - row;
                    return Expanded(
                      child: Row(
                        children: List.generate(8, (col) {
                          final position = Position(boardRow, col);
                          return Expanded(
                            child: ChessSquare(position: position),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
