import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../board/utils/exporter.dart';
import '../../modes/modes_enum.dart';
import '../../ui/piece_renderer.dart';
import '../../ui/board_theme.dart';
import '../../debug.dart';
import 'custom_board_controller.dart';
import '../../management/utils.dart';

/// Lightweight drag data to prevent stale piece references
class _DragData {
  final PieceType pieceType;
  final PieceColor pieceColor;
  final Position fromPosition;

  const _DragData({
    required this.pieceType,
    required this.pieceColor,
    required this.fromPosition,
  });
}

/// Development board setup page - allows custom piece placement and game mode testing
/// OPTIMIZED: Uses GetX controller with ID-based updates for 60 FPS performance
class CustomBoardSetupPage extends StatelessWidget {
  const CustomBoardSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller once
    final controller = Get.put(CustomBoardController(), tag: 'custom_board');

    // Get the game type from route arguments
    final args = Get.arguments as Map<String, dynamic>?;
    final gameType = args?['gameType'] ?? ModesEnum.classic;

    printDebug('🔙 CUSTOM BOARD SETUP: args=$args');

    // Check if returning from a game with saved state
    final pieces = args?['pieces'] as List<ChessPiece>?;
    final currentPlayer = args?['currentPlayer'] as PieceColor?;

    if (pieces != null && pieces.isNotEmpty) {
      printDebug('🔙 CUSTOM BOARD: Restoring ${pieces.length} pieces');
      controller.initialize(
        gameType: gameType,
        pieces: pieces,
        currentPlayer: currentPlayer,
      );
      printDebug(
        '🔙 CUSTOM BOARD: Restored state - ${pieces.length} pieces, turn: ${currentPlayer?.name ?? 'white'}',
      );
    } else {
      printDebug('🔙 CUSTOM BOARD: Loading standard start position');
      controller.initialize(gameType: gameType);
    }

    return _CustomBoardScaffold(controller: controller);
  }
}

/// Main scaffold for CUSTOM BOARD setup
class _CustomBoardScaffold extends StatelessWidget {
  final CustomBoardController controller;

  const _CustomBoardScaffold({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            // Game Mode & Turn Selector
            _CustomControlPanel(controller: controller),

            // Chess Board
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: _CustomBoard(controller: controller),
                ),
              ),
            ),

            // Piece Selector
            _CustomPieceSelector(controller: controller),

            // Action Buttons
            _CustomActionButtons(controller: controller),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('CUSTOM BOARD Setup'),
      backgroundColor: Colors.purple.shade700,
      actions: [
        // Board theme selector
        GetBuilder<CustomBoardController>(
          id: 'board_theme',
          tag: 'custom_board',
          builder: (_) => PopupMenuButton<BoardTheme>(
            icon: const Icon(Icons.palette),
            tooltip: 'Board Theme',
            onSelected: controller.setBoardTheme,
            itemBuilder: (context) => BoardTheme.values
                .map(
                  (theme) => PopupMenuItem(
                    value: theme,
                    child: Row(
                      children: [
                        Icon(
                          controller.boardTheme == theme
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(theme.displayName),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () => _showInstructions(context),
          tooltip: 'Instructions',
        ),
      ],
    );
  }

  void _showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CUSTOM BOARD Instructions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Select game mode and starting turn'),
              SizedBox(height: 8),
              Text('2. Choose piece color from bottom'),
              SizedBox(height: 8),
              Text('3. Tap a piece type to select it'),
              SizedBox(height: 8),
              Text('4. Tap squares to place pieces'),
              SizedBox(height: 8),
              Text('5. Drag pieces to move them around'),
              SizedBox(height: 8),
              Text('6. Drag pieces to trash area to remove'),
              SizedBox(height: 8),
              Text('7. Both kings must be present to start'),
              SizedBox(height: 8),
              Text('8. Use Reset to load standard position'),
              SizedBox(height: 8),
              Text('9. Use Clear to empty the board'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

/// OPTIMIZED: Control panel with ID-based GetBuilder updates
class _CustomControlPanel extends StatelessWidget {
  final CustomBoardController controller;

  const _CustomControlPanel({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomBoardController>(
      id: 'control_panel',
      tag: 'custom_board',
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade200,
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ModesEnum>(
                value: controller.selectedGameType,
                decoration: const InputDecoration(
                  labelText: 'Game Mode',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: ModesEnum.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.setGameType(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<PieceColor>(
                value: controller.currentTurnColor,
                decoration: const InputDecoration(
                  labelText: 'Turn',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(
                    value: PieceColor.white,
                    child: Text('White'),
                  ),
                  DropdownMenuItem(
                    value: PieceColor.black,
                    child: Text('Black'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.setCurrentTurnColor(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// OPTIMIZED: Board with GetBuilder for theme changes only
class _CustomBoard extends StatelessWidget {
  final CustomBoardController controller;

  const _CustomBoard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.purple.shade800, width: 4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // Board background - only updates on theme change
            GetBuilder<CustomBoardController>(
              id: 'board_theme',
              tag: 'custom_board',
              builder: (_) => Positioned.fill(
                child: controller.boardTheme.getImage(fit: BoxFit.cover),
              ),
            ),
            // Grid of squares - each square updates independently
            Column(
              children: List.generate(8, (row) {
                final boardRow = 7 - row;
                return Expanded(
                  child: Row(
                    children: List.generate(8, (col) {
                      final position = Position(boardRow, col);
                      return Expanded(
                        child: _CustomSquare(
                          position: position,
                          controller: controller,
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// OPTIMIZED: Individual square with ID-based updates - only rebuilds when its piece changes
class _CustomSquare extends StatelessWidget {
  final Position position;
  final CustomBoardController controller;

  const _CustomSquare({required this.position, required this.controller});

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Only this specific square rebuilds when 'square_a1' (etc.) is updated
    return GetBuilder<CustomBoardController>(
      id: squareIdFromPosition(position),
      tag: 'custom_board',
      builder: (_) {
        final piece = controller.getPieceAt(position);

        return DragTarget<_DragData>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) {
            final dragData = details.data;
            // Check if piece is from selector (dummy position -1,-1)
            if (dragData.fromPosition.row == -1) {
              // Place piece from selector at this position
              controller.placePieceFromSelector(
                position,
                dragData.pieceType,
                dragData.pieceColor,
              );
            } else {
              // Move piece from one board position to another
              controller.movePieceFromTo(dragData.fromPosition, position);
            }
          },
          builder: (context, candidateData, rejectedData) {
            final isHighlighted = candidateData.isNotEmpty;

            return GestureDetector(
              onTap: () => controller.placePiece(position),
              child: Container(
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.transparent,
                  border: Border.all(
                    color: isHighlighted ? Colors.green : Colors.black12,
                    width: isHighlighted ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: piece != null
                      ? Draggable<_DragData>(
                          data: _DragData(
                            pieceType: piece.type,
                            pieceColor: piece.color,
                            fromPosition: piece.position,
                          ),
                          feedback: Material(
                            color: Colors.transparent,
                            child: piece.toWidget(size: 50),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: piece.toWidget(size: 45),
                          ),
                          child: piece.toWidget(size: 45),
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// OPTIMIZED: Piece selector with separate sections
class _CustomPieceSelector extends StatelessWidget {
  final CustomBoardController controller;

  const _CustomPieceSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return DragTarget<_DragData>(
      // Accept pieces being dragged off the board to remove them
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final dragData = details.data;
        // Only remove if dragging from board (not from selector)
        if (dragData.fromPosition.row != -1) {
          controller.removePieceAt(dragData.fromPosition);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: isHighlighted ? Colors.red.shade100 : Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Select Piece to Place:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (isHighlighted) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Drop to remove',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // PERFORMANCE: Controls only rebuild when needed
              _PieceSelectorControls(controller: controller),
              const SizedBox(height: 12),
              // PERFORMANCE: Piece list only rebuilds when color changes
              _PieceList(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

/// PERFORMANCE: Separate controls to minimize rebuilds
class _PieceSelectorControls extends StatelessWidget {
  final CustomBoardController controller;

  const _PieceSelectorControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomBoardController>(
      id: 'piece_color',
      tag: 'custom_board',
      builder: (_) => Row(
        children: [
          // Color selector
          ChoiceChip(
            label: const Text('White'),
            selected: controller.selectedPieceColor == PieceColor.white,
            onSelected: (selected) {
              if (selected) {
                controller.setSelectedPieceColor(PieceColor.white);
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Black'),
            selected: controller.selectedPieceColor == PieceColor.black,
            onSelected: (selected) {
              if (selected) {
                controller.setSelectedPieceColor(PieceColor.black);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// PERFORMANCE: Piece list only rebuilds when color changes
class _PieceList extends StatelessWidget {
  final CustomBoardController controller;

  const _PieceList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomBoardController>(
      id: 'piece_color',
      tag: 'custom_board',
      builder: (_) {
        final currentColor = controller.selectedPieceColor;

        return SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: PieceType.values.length,
            cacheExtent: 300,
            itemBuilder: (context, index) {
              final type = PieceType.values[index];

              // PERFORMANCE: Each piece button is isolated
              return RepaintBoundary(
                child: _PieceButton(
                  key: ValueKey('${currentColor.name}_$type'),
                  type: type,
                  color: currentColor,
                  controller: controller,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// PERFORMANCE: Individual piece button with its own GetBuilder
class _PieceButton extends StatelessWidget {
  final PieceType type;
  final PieceColor color;
  final CustomBoardController controller;

  const _PieceButton({
    super.key,
    required this.type,
    required this.color,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: Only this button rebuilds when selection changes to/from this type
    return GetBuilder<CustomBoardController>(
      id: 'piece_type',
      tag: 'custom_board',
      builder: (_) {
        final isSelected = controller.selectedPieceType == type;

        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Draggable<_DragData>(
            data: _DragData(
              pieceType: type,
              pieceColor: color,
              fromPosition: Position(-1, -1), // Dummy position for selector
            ),
            feedback: Material(
              color: Colors.transparent,
              child: ChessPiece(
                type: type,
                color: color,
                position: Position(0, 0),
              ).toWidget(size: 50),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildButton(isSelected),
            ),
            child: _buildButton(isSelected),
          ),
        );
      },
    );
  }

  Widget _buildButton(bool isSelected) {
    return InkWell(
      onTap: () => controller.setSelectedPieceType(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? Colors.purple.shade100 : Colors.grey.shade200,
          border: Border.all(
            color: isSelected ? Colors.purple.shade700 : Colors.grey.shade400,
            width: isSelected ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: ChessPiece(
            type: type,
            color: color,
            position: Position(0, 0),
          ).toWidget(size: 38),
        ),
      ),
    );
  }
}

/// OPTIMIZED: Action buttons
class _CustomActionButtons extends StatelessWidget {
  final CustomBoardController controller;

  const _CustomActionButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller.loadStandardStartPosition,
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Start'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: controller.clearBoard,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Board'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _startGame(context, controller),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startGame(BuildContext context, CustomBoardController controller) {
    // Validate board
    if (!controller.validateBoard()) {
      // Use post-frame callback to avoid calling snackbar during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          'Invalid Board',
          'Both white and black kings must be present',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      });
      return;
    }

    // Navigate to game
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.toNamed(
        '/game',
        arguments: {
          'gameType': controller.selectedGameType,
          'customBoard': controller.customPieces,
          'currentPlayer': controller.currentTurnColor,
          'isDevBoard': true,
          // Store original pieces and player for back navigation
          'devBoardOriginalPieces': List<ChessPiece>.from(
            controller.customPieces,
          ),
          'devBoardOriginalPlayer': controller.currentTurnColor,
        },
      );
    });
  }
}
