import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../board/utils/exporter.dart';
import '../../modes/modes_enum.dart';
import '../../ui/piece_renderer.dart';
import '../../ui/board_theme.dart';
import '../../services/api_service.dart';
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
    // Get the game type from route arguments BEFORE controller lookup
    final args = Get.arguments as Map<String, dynamic>?;
    final gameType = args?['gameType'] ?? ModesEnum.classic;

    // Check for FEN string (preferred - simple string serialization)
    final fen = args?['fen'] as String?;

    // Legacy support: check for pieces list
    final pieces = args?['pieces'] as List<ChessPiece>?;
    final currentPlayer = args?['currentPlayer'] as PieceColor?;
    final whiteDifficulty = args?['whiteDifficulty'] as int?;
    final blackDifficulty = args?['blackDifficulty'] as int?;

    // DEBUG: Print what we received
    debugPrint(
      'CustomBoardSetupPage: fen=$fen, pieces=${pieces?.length}, gameType=$gameType',
    );

    // Check if controller exists and get or create it
    final controller = Get.put(
      CustomBoardController(),
      tag: 'custom_board',
      permanent: true,
    );

    // IMMEDIATE initialization if we have FEN or pieces from arguments
    // This runs synchronously during build, before any UI is shown
    if (fen != null && fen.isNotEmpty) {
      debugPrint('CustomBoardSetupPage: Initializing from FEN: $fen');
      // Use microtask to avoid setState during build but run immediately after
      Future.microtask(() {
        controller.forceInitializeFromFEN(
          gameType: gameType,
          fen: fen,
          whiteDifficulty: whiteDifficulty,
          blackDifficulty: blackDifficulty,
        );
      });
    } else if (pieces != null && pieces.isNotEmpty) {
      debugPrint('CustomBoardSetupPage: Initializing from pieces list');
      Future.microtask(() {
        controller.forceInitialize(
          gameType: gameType,
          pieces: pieces,
          currentPlayer: currentPlayer,
          whiteDifficulty: whiteDifficulty,
          blackDifficulty: blackDifficulty,
        );
      });
    } else if (!controller.isInitialized) {
      debugPrint('CustomBoardSetupPage: First time init');
      Future.microtask(() {
        controller.initialize(gameType: gameType);
      });
    } else {
      debugPrint('CustomBoardSetupPage: Keeping existing state');
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Get.offAllNamed('/'),
        tooltip: 'Back to Home',
      ),
      title: const Text('CUSTOM BOARD Setup'),
      backgroundColor: Colors.purple.shade700,
      actions: [
        // Database reset button
        IconButton(
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _showResetDatabaseDialog(context),
          tooltip: 'Reset Database',
        ),
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

  Future<void> _showResetDatabaseDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database?'),
        content: const Text(
          'This will delete ALL game records from the database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final apiService = ApiService();
        final result = await apiService.resetDatabase();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Database reset! Games: ${result['game_records_deleted']}, Moves: ${result['move_records_deleted']}',
              ),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
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
                initialValue: controller.selectedGameType,
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
                initialValue: controller.currentTurnColor,
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
class _CustomActionButtons extends StatefulWidget {
  final CustomBoardController controller;

  const _CustomActionButtons({required this.controller});

  @override
  State<_CustomActionButtons> createState() => _CustomActionButtonsState();
}

class _CustomActionButtonsState extends State<_CustomActionButtons> {
  final ApiService _apiService = ApiService();
  bool _isStartingOnline = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Compact Difficulty Sliders Section
          GetBuilder<CustomBoardController>(
            id: 'bot_difficulty',
            tag: 'custom_board',
            builder: (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // White difficulty - compact
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '⚪${widget.controller.whiteDifficulty}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: widget.controller.whiteDifficulty
                                  .toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              onChanged: (v) =>
                                  widget.controller.whiteDifficulty = v.toInt(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Black difficulty - compact
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '⚫${widget.controller.blackDifficulty}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: widget.controller.blackDifficulty
                                  .toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              onChanged: (v) =>
                                  widget.controller.blackDifficulty = v.toInt(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.controller.loadStandardStartPosition,
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.controller.clearBoard,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startGame(context, widget.controller),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Online Bot vs Bot button (made smaller)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isStartingOnline
                  ? null
                  : () => _startOnlineBotVsBot(context),
              icon: _isStartingOnline
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload, size: 18),
              label: Text(
                _isStartingOnline ? 'Starting...' : '🌐 Online Bot vs Bot',
                style: const TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startOnlineBotVsBot(BuildContext context) async {
    // Validate board
    if (!widget.controller.validateBoard()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Both white and black kings must be present'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isStartingOnline = true;
    });

    try {
      // Test connection
      final isReachable = await _apiService.testConnection();
      if (!isReachable) {
        throw Exception('Backend server is not reachable');
      }

      await _apiService.loginAsGuest();

      // Convert pieces to API format
      final pieces = widget.controller.customPieces.map((p) {
        return {
          'type': p.type.name,
          'color': p.color == PieceColor.white ? 'white' : 'black',
          'position': p.position.algebraic,
        };
      }).toList();

      final result = await _apiService.createCustomBoardBotVsBotGame(
        mode: widget.controller.selectedGameType.toSnakeCase(),
        pieces: pieces,
        currentPlayer: widget.controller.currentTurnColor == PieceColor.white
            ? 'white'
            : 'black',
        whiteDifficulty: widget.controller.whiteDifficulty,
        blackDifficulty: widget.controller.blackDifficulty,
        autoPlay: true,
        moveDelay: 2000,
      );

      final gameId = result['game_id'];

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Game started: $gameId'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to spectator view, preserving state for back navigation
      Get.toNamed(
        '/game',
        arguments: {
          'gameType': widget.controller.selectedGameType,
          'isOnline': true,
          'isSpectator': true,
          'gameId': gameId,
          // Mark as dev board so navigateBack() returns to custom board
          'isDevBoard': true,
          // Store original pieces for back navigation
          'devBoardOriginalPieces': List<ChessPiece>.from(
            widget.controller.customPieces,
          ),
          'devBoardOriginalPlayer': widget.controller.currentTurnColor,
          // Also preserve difficulty settings
          'whiteDifficulty': widget.controller.whiteDifficulty,
          'blackDifficulty': widget.controller.blackDifficulty,
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingOnline = false;
        });
      }
    }
  }

  void _startGame(BuildContext context, CustomBoardController controller) {
    // Validate board
    if (!controller.validateBoard()) {
      // Use ScaffoldMessenger instead of Get.snackbar to avoid Overlay issues
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Both white and black kings must be present'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
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
