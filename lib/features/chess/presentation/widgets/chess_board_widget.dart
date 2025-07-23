import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/position.dart';
import '../controllers/chess_controller.dart';
import 'chess_square.dart';

class ChessBoardWidget extends StatelessWidget {
  const ChessBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    print('DEBUG: ChessBoardWidget.build() called');
    return Obx(() {
      final controller = Get.find<ChessController>();
      print(
        'DEBUG: ChessBoardWidget Obx rebuilding - board has ${controller.board.pieces.length} pieces',
      );
      return Container(
        padding: const EdgeInsets.all(
          16.0,
        ), // Increased from 8.0 for bigger board
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown.shade800, width: 4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.brown.shade600, width: 2),
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
    });
  }
}
