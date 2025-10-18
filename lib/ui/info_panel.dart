import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/chess_controller.dart';
import '../board/exporter.dart';

class InfoPanel extends StatelessWidget {
  final bool isTopPanel;

  const InfoPanel({super.key, required this.isTopPanel});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ChessController>(
      builder: (controller) {
        final displayColor = isTopPanel ? PieceColor.black : PieceColor.white;
        final isCurrentPlayer = controller.currentPlayer == displayColor;

        return Container(
          margin: const EdgeInsets.all(8.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isCurrentPlayer
                ? Colors.green.shade100
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCurrentPlayer
                  ? Colors.green.shade400
                  : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.circle,
                    color: displayColor == PieceColor.white
                        ? Colors.white
                        : Colors.black,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayColor == PieceColor.white ? 'WHITE' : 'BLACK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: displayColor == PieceColor.white
                          ? Colors.grey.shade800
                          : Colors.black,
                    ),
                  ),
                  if (isCurrentPlayer) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.play_arrow,
                      color: Colors.green.shade600,
                      size: 16,
                    ),
                  ],
                ],
              ),

              // Game status for current player (simplified)
              if (isCurrentPlayer && controller.statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    controller.statusMessage,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: controller.gameStatus.name.contains('check')
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
