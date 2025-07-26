import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/position.dart';
import '../../domain/enums/piece_color.dart';
import '../controllers/chess_controller.dart';

class ChessSquare extends StatelessWidget {
  final Position position;

  const ChessSquare({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = Get.find<ChessController>();

      // In chess, a1 (0,0) should be a dark square
      // So when (row + col) is even, it should be dark
      final isLight = (position.row + position.col) % 2 != 0;
      final isSelected = controller.isSelectedPosition(position);
      final isValidMove = controller.isValidMoveTarget(position);
      final piece = controller.getPieceSymbol(position);
      final pieceColor = controller.getPieceColor(position);

      return Material(
        color: _getSquareColor(isLight, isSelected, isValidMove),
        child: InkWell(
          splashColor: Colors.blue.withOpacity(0.3),
          highlightColor: Colors.blue.withOpacity(0.1),
          onTap: () {
            print('🎯 CHESS SQUARE TAPPED: ${position.algebraic}');
            try {
              controller.onSquareSelected(position);
              print('✅ Controller method called successfully');
            } catch (e) {
              print('❌ Error calling controller: $e');
            }
          },
          child: Container(
            decoration: isSelected
                ? BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                  )
                : null,
            child: Stack(
              children: [
                // Valid move indicator
                if (isValidMove)
                  Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: piece != null
                            ? Colors.red.withValues(alpha: 0.8)
                            : Colors.green.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: piece != null
                            ? Border.all(color: Colors.red.shade900, width: 2)
                            : null,
                      ),
                    ),
                  ),

                // Chess piece
                if (piece != null)
                  Center(
                    child: Text(
                      piece,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        // Yellowish color for white pieces - good contrast on both squares
                        color: pieceColor == PieceColor.white
                            ? Colors
                                  .amber
                                  .shade600 // Yellowish color for white pieces
                            : Colors.black,
                        // Simple consistent shadow for all pieces
                        shadows: [
                          Shadow(
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                            color: pieceColor == PieceColor.white
                                ? Colors.black38
                                : Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Coordinate labels (for debugging)
                if (_shouldShowCoordinates())
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Text(
                      position.algebraic,
                      style: TextStyle(
                        fontSize: 8,
                        color: isLight ? Colors.black54 : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Color _getSquareColor(bool isLight, bool isSelected, bool isValidMove) {
    if (isSelected) {
      return Colors.yellow.shade300;
    }

    if (isValidMove) {
      return isLight ? Colors.lightGreen.shade200 : Colors.green.shade400;
    }

    // Better chess board colors with higher contrast
    return isLight ? Colors.grey.shade200 : Colors.brown.shade600;
  }

  bool _shouldShowCoordinates() {
    // Show coordinates for better user experience
    return true; // Re-enabled as requested
  }
}
