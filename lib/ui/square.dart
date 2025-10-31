import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/exporter.dart';
import '../management/controller.dart';
import '../constants.dart';

class ChessSquare extends StatelessWidget {
  final Position position;

  const ChessSquare({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = Get.find<Controller>();

      // In chess, a1 (0,0) should be a dark square
      // So when (row + col) is even, it should be dark
      final isLight = (position.row + position.col) % 2 != 0;
      final isSelected = controller.isSelectedPosition(position);
      final isValidMove = controller.isValidMoveTarget(position);
      final piece = controller.getPieceSymbol(position);
      final pieceColor = controller.getPieceColor(position);

      // SNARE MODE: Check if this square is in an entangle zone
      final isEntangleZone = controller.isPositionInEntangleZone(position);
      final hasEntangledPiece =
          piece != null && controller.isPieceEntangled(position);

      return Material(
        color: _getSquareColor(
          isLight,
          isSelected,
          isValidMove,
          isEntangleZone,
        ),
        child: InkWell(
          splashColor: Colors.blue.withValues(alpha: 0.3),
          highlightColor: Colors.blue.withValues(alpha: 0.1),
          onTap: () {
            try {
              controller.onSquareSelected(position);
            } catch (e) {
              // Log error during development, silent in production
              if (AppConstants.enableDebugLogs) {
                print('❌ Error selecting square ${position.algebraic}: $e');
              }
            }
          },
          child: Container(
            decoration: isSelected
                ? BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 3),
                  )
                : hasEntangledPiece
                ? BoxDecoration(
                    border: Border.all(color: Colors.purple.shade700, width: 3),
                  )
                : null,
            child: Stack(
              children: [
                // Entangle zone indicator
                if (isEntangleZone && piece == null)
                  Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.purple.shade600,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.purple.shade900,
                      ),
                    ),
                  ),

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

                // Entangled piece indicator overlay
                if (hasEntangledPiece)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.link, size: 12, color: Colors.white),
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

  Color _getSquareColor(
    bool isLight,
    bool isSelected,
    bool isValidMove,
    bool isEntangleZone,
  ) {
    if (isSelected) {
      return Colors.yellow.shade300;
    }

    if (isValidMove) {
      return isLight ? Colors.lightGreen.shade200 : Colors.green.shade400;
    }

    // SNARE MODE: Entangle zone gets a purple tint
    if (isEntangleZone) {
      return isLight ? Colors.purple.shade100 : Colors.purple.shade400;
    }

    // Classic chess board colors
    return isLight ? Colors.grey.shade200 : Colors.brown.shade600;
  }

  bool _shouldShowCoordinates() {
    // Show coordinates for better user experience
    return true; // Re-enabled as requested
  }
}
