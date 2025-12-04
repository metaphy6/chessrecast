import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../management/utils.dart';
import '../board/utils/exporter.dart';
import '../management/controller.dart';
import 'piece_renderer.dart';

// Cached border decorations to avoid rebuilding BoxDecoration on every frame
class _BorderDecorations {
  static const selected = BoxDecoration(
    border: Border.fromBorderSide(BorderSide(color: Colors.blue, width: 3)),
  );

  static final entangled = BoxDecoration(
    border: Border.all(color: Colors.purple.shade700, width: 3),
  );
}

// Cached color overlays to eliminate allocations
class _ColorOverlays {
  static final selected = Colors.yellow.withValues(alpha: 0.5);
  static final validMove = Colors.green.withValues(alpha: 0.3);
  static final entangleZone = Colors.purple.withValues(alpha: 0.2);
  static const transparent = Colors.transparent;
}

class ChessSquare extends StatelessWidget {
  final Position position;

  const ChessSquare({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    // Use GetBuilder with specific ID for this position - much more efficient
    return GetBuilder<Controller>(
      id: squareIdFromPosition(position),
      builder: (controller) {
        // In chess, a1 (0,0) should be a dark square
        // So when (row + col) is even, it should be dark
        final isLight = (position.row + position.col) % 2 != 0;
        final isSelected = controller.isSelectedPosition(position);
        final isValidMove = controller.isValidMoveTarget(position);
        final chessPiece = controller.getPieceAt(position);

        // SNARE MODE: Check if this square is in an entangle zone
        final isEntangleZone = controller.isPositionInEntangleZone(position);
        final hasEntangledPiece =
            chessPiece != null && controller.isPieceEntangled(position);

        return GestureDetector(
          onTap: () {
            try {
              controller.onSquareSelected(position);
            } catch (e) {
              // Log error silently in production
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: _getSquareColor(
              isLight,
              isSelected,
              isValidMove,
              isEntangleZone,
            ),
            child: Container(
              decoration: isSelected
                  ? _BorderDecorations.selected
                  : hasEntangledPiece
                  ? _BorderDecorations.entangled
                  : null,
              child: Stack(
                children: [
                  // Valid move indicator (render first, underneath)
                  if (isValidMove)
                    _ValidMoveIndicator(
                      hasCapture:
                          chessPiece != null &&
                          !controller.isTeleportSwapTarget(
                            position,
                            chessPiece,
                          ),
                    ),

                  // Entangle zone indicator (under pieces)
                  if (isEntangleZone && chessPiece == null)
                    const _EntangleZoneIndicator(),

                  // Chess piece (main content, rendered on top)
                  if (chessPiece != null)
                    Center(child: chessPiece.toWidget(size: 45)),

                  // Entangled piece indicator overlay (small badge)
                  if (hasEntangledPiece)
                    const Positioned(
                      bottom: 2,
                      right: 2,
                      child: _EntangledBadge(),
                    ),

                  // Coordinate labels (development only)
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
      },
    );
  }

  Color _getSquareColor(
    bool isLight,
    bool isSelected,
    bool isValidMove,
    bool isEntangleZone,
  ) {
    // Since we're using a background image, make squares transparent
    // Only add color overlays for selected/valid moves
    if (isSelected) {
      return _ColorOverlays.selected;
    }

    if (isValidMove) {
      return _ColorOverlays.validMove;
    }

    // SNARE MODE: Entangle zone gets a purple tint
    if (isEntangleZone) {
      return _ColorOverlays.entangleZone;
    }

    // Transparent for normal squares to show board image
    return _ColorOverlays.transparent;
  }

  // Const value to avoid method call overhead
  static const bool _showCoordinates = true;

  bool _shouldShowCoordinates() {
    return _showCoordinates;
  }
}

/// Const widget for entangled piece badge - prevents rebuilds
class _EntangledBadge extends StatelessWidget {
  const _EntangledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.purple.shade800,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.link, size: 12, color: Colors.white),
    );
  }
}

/// Const widget for entangle zone indicator - prevents rebuilds
class _EntangleZoneIndicator extends StatelessWidget {
  const _EntangleZoneIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.purple.shade600, width: 2),
        ),
        child: Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: Colors.purple.shade900,
        ),
      ),
    );
  }
}

/// Optimized valid move indicator widget with cached decorations
class _ValidMoveIndicator extends StatelessWidget {
  final bool hasCapture;

  const _ValidMoveIndicator({required this.hasCapture});

  // Cached decorations for performance
  static final _captureDecoration = BoxDecoration(
    color: Colors.red.withValues(alpha: 0.8),
    shape: BoxShape.circle,
    border: Border.all(color: Colors.red.shade900, width: 2),
  );

  static final _moveDecoration = BoxDecoration(
    color: Colors.green.withValues(alpha: 0.6),
    shape: BoxShape.circle,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 20,
        height: 20,
        decoration: hasCapture ? _captureDecoration : _moveDecoration,
      ),
    );
  }
}
