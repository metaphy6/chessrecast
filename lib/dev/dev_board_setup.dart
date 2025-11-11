import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/exporter.dart';
import '../modes/modes_enum.dart';
import '../ui/piece_renderer.dart';
import '../ui/board_theme.dart';
import '../debug.dart';

/// Development board setup page - allows custom piece placement and game mode testing
class DevBoardSetupPage extends StatefulWidget {
  const DevBoardSetupPage({super.key});

  @override
  State<DevBoardSetupPage> createState() => _DevBoardSetupPageState();
}

class _DevBoardSetupPageState extends State<DevBoardSetupPage> {
  late ModesEnum selectedGameType;
  PieceColor currentTurnColor = PieceColor.white;
  List<ChessPiece> customPieces = [];

  // Currently selected piece type for placement
  PieceType? selectedPieceType;
  PieceColor selectedPieceColor = PieceColor.white;

  // Board theme
  BoardTheme boardTheme = BoardTheme.brown;

  @override
  void initState() {
    super.initState();
    // Get the game type from route arguments, default to classic if not provided
    final args = Get.arguments as Map<String, dynamic>?;
    selectedGameType = args?['gameType'] ?? ModesEnum.classic;

    printDebug('🔙 DEV BOARD SETUP initState: args=$args');

    // Check if returning from a game with saved state
    if (args?['pieces'] != null && args?['pieces'] is List<ChessPiece>) {
      printDebug(
        '🔙 DEV BOARD: Restoring ${(args!['pieces'] as List).length} pieces',
      );
      customPieces = List<ChessPiece>.from(args['pieces'] as List<ChessPiece>);
      currentTurnColor =
          args['currentPlayer'] as PieceColor? ?? PieceColor.white;
      printDebug(
        '🔙 DEV BOARD: Restored state - ${customPieces.length} pieces, turn: ${currentTurnColor.name}',
      );
    } else {
      printDebug('🔙 DEV BOARD: Loading standard start position');
      _loadStandardStartPosition();
    }
  }

  void _loadStandardStartPosition() {
    setState(() {
      customPieces = List<ChessPiece>.from(ChessBoard.initial().pieces);
    });
  }

  void _clearBoard() {
    setState(() {
      customPieces.clear();
    });
  }

  ChessPiece? _getPieceAt(Position position) {
    try {
      return customPieces.firstWhere((p) => p.position == position);
    } catch (e) {
      return null;
    }
  }

  void _placePiece(Position position) {
    if (selectedPieceType == null) {
      // Remove piece if no piece type selected
      setState(() {
        customPieces.removeWhere((p) => p.position == position);
      });
    } else {
      setState(() {
        // Remove existing piece at this position
        customPieces.removeWhere((p) => p.position == position);
        // Add new piece
        customPieces.add(
          ChessPiece(
            type: selectedPieceType!,
            color: selectedPieceColor,
            position: position,
          ),
        );
      });
    }
  }

  void _startGame() {
    // Validate board has at least both kings
    final whiteKing = customPieces.any(
      (p) => p.type == PieceType.king && p.color == PieceColor.white,
    );
    final blackKing = customPieces.any(
      (p) => p.type == PieceType.king && p.color == PieceColor.black,
    );

    if (!whiteKing || !blackKing) {
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

    // Use post-frame callback to avoid navigation during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.toNamed(
        '/game',
        arguments: {
          'gameType': selectedGameType,
          'customBoard': customPieces,
          'currentPlayer': currentTurnColor,
          'isDevBoard': true,
          // Store original pieces and player for back navigation
          'devBoardOriginalPieces': List<ChessPiece>.from(customPieces),
          'devBoardOriginalPlayer': currentTurnColor,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Board Setup'),
        backgroundColor: Colors.purple.shade700,
        actions: [
          // Board theme selector
          PopupMenuButton<BoardTheme>(
            icon: const Icon(Icons.palette),
            tooltip: 'Board Theme',
            onSelected: (theme) {
              setState(() => boardTheme = theme);
            },
            itemBuilder: (context) => BoardTheme.values
                .map(
                  (theme) => PopupMenuItem(
                    value: theme,
                    child: Row(
                      children: [
                        Icon(
                          boardTheme == theme
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInstructions(),
            tooltip: 'Instructions',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Game Mode & Turn Selector
            _buildControlPanel(),

            // Chess Board
            Expanded(
              child: Center(
                child: AspectRatio(aspectRatio: 1.0, child: _buildDevBoard()),
              ),
            ),

            // Piece Selector
            _buildPieceSelector(),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade200,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ModesEnum>(
                  value: selectedGameType,
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
                      setState(() => selectedGameType = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<PieceColor>(
                  value: currentTurnColor,
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
                      setState(() => currentTurnColor = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDevBoard() {
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
            // Board background image
            Positioned.fill(child: boardTheme.getImage(fit: BoxFit.cover)),
            // Grid of squares
            Column(
              children: List.generate(8, (row) {
                final boardRow = 7 - row;
                return Expanded(
                  child: Row(
                    children: List.generate(8, (col) {
                      final position = Position(boardRow, col);
                      return Expanded(child: _buildDevSquare(position));
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

  Widget _buildDevSquare(Position position) {
    final piece = _getPieceAt(position);

    return DragTarget<ChessPiece>(
      onWillAcceptWithDetails: (details) =>
          true, // Accept any piece being dragged
      onAcceptWithDetails: (details) {
        final draggedPiece = details.data;
        setState(() {
          // Remove piece from its old position if it was on the board
          customPieces.removeWhere((p) => p.position == draggedPiece.position);
          // Add piece to new position
          customPieces.add(draggedPiece.copyWith(position: position));
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: () => _placePiece(position),
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
                  ? Draggable<ChessPiece>(
                      data: piece,
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
  }

  Widget _buildPieceSelector() {
    return DragTarget<ChessPiece>(
      // Accept pieces being dragged off the board to remove them
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final draggedPiece = details.data;
        setState(() {
          // Remove piece from board when dropped on selector area
          customPieces.removeWhere((p) => p.position == draggedPiece.position);
        });
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
              Row(
                children: [
                  // Color selector
                  ChoiceChip(
                    label: const Text('White'),
                    selected: selectedPieceColor == PieceColor.white,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedPieceColor = PieceColor.white);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Black'),
                    selected: selectedPieceColor == PieceColor.black,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedPieceColor = PieceColor.black);
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  const Spacer(),
                  // Remove button
                  InkWell(
                    onTap: () {
                      setState(() => selectedPieceType = null);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selectedPieceType == null
                            ? Colors.red.shade100
                            : Colors.grey.shade200,
                        border: Border.all(
                          color: selectedPieceType == null
                              ? Colors.red.shade700
                              : Colors.grey.shade400,
                          width: selectedPieceType == null ? 3 : 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear,
                            size: 20,
                            color: selectedPieceType == null
                                ? Colors.red.shade900
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Remove',
                            style: TextStyle(
                              fontWeight: selectedPieceType == null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selectedPieceType == null
                                  ? Colors.red.shade900
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: PieceType.values.map((type) {
                    final piece = ChessPiece(
                      type: type,
                      color: selectedPieceColor,
                      position: Position(0, 0), // Dummy position for display
                    );
                    final isSelected = selectedPieceType == type;

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Draggable<ChessPiece>(
                        data: ChessPiece(
                          type: type,
                          color: selectedPieceColor,
                          // Use a dummy position that won't match any board position
                          position: Position(-1, -1),
                        ),
                        feedback: Material(
                          color: Colors.transparent,
                          child: piece.toWidget(size: 50),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: InkWell(
                            onTap: () {
                              setState(() => selectedPieceType = type);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.purple.shade100
                                    : Colors.grey.shade200,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.purple.shade700
                                      : Colors.grey.shade400,
                                  width: isSelected ? 3 : 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(child: piece.toWidget(size: 38)),
                            ),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() => selectedPieceType = type);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.purple.shade100
                                  : Colors.grey.shade200,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.purple.shade700
                                    : Colors.grey.shade400,
                                width: isSelected ? 3 : 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: piece.toWidget(size: 38)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loadStandardStartPosition,
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Start'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearBoard,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Board'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _startGame,
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

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dev Board Instructions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Select game mode and starting turn'),
              SizedBox(height: 8),
              Text('2. Choose piece color and type from bottom'),
              SizedBox(height: 8),
              Text('3. Tap squares to place/remove pieces'),
              SizedBox(height: 8),
              Text('4. Both kings must be present to start'),
              SizedBox(height: 8),
              Text('5. Use Reset to load standard position'),
              SizedBox(height: 8),
              Text('6. Use Clear to empty the board'),
              SizedBox(height: 8),
              Text('7. Click Start Game when ready'),
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
