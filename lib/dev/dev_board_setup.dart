import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../board/exporter.dart';

/// Development board setup page - allows custom piece placement and game mode testing
class DevBoardSetupPage extends StatefulWidget {
  const DevBoardSetupPage({super.key});

  @override
  State<DevBoardSetupPage> createState() => _DevBoardSetupPageState();
}

class _DevBoardSetupPageState extends State<DevBoardSetupPage> {
  GameType selectedGameType = GameType.classic;
  PieceColor currentTurnColor = PieceColor.white;
  List<ChessPiece> customPieces = [];

  // Currently selected piece type for placement
  PieceType? selectedPieceType;
  PieceColor selectedPieceColor = PieceColor.white;

  @override
  void initState() {
    super.initState();
    _loadStandardStartPosition();
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
      Get.snackbar(
        'Invalid Board',
        'Both white and black kings must be present',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
      return;
    }

    // Create custom board and navigate to game
    Get.toNamed(
      '/game',
      arguments: {
        'gameType': selectedGameType,
        'customBoard': customPieces,
        'currentPlayer': currentTurnColor,
        'isDevBoard': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Board Setup'),
        backgroundColor: Colors.purple.shade700,
        actions: [
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
                child: DropdownButtonFormField<GameType>(
                  value: selectedGameType,
                  decoration: const InputDecoration(
                    labelText: 'Game Mode',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: GameType.values.map((type) {
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
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.purple.shade600, width: 2),
        ),
        child: Column(
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
      ),
    );
  }

  Widget _buildDevSquare(Position position) {
    final isLight = (position.row + position.col) % 2 == 0;
    final piece = _getPieceAt(position);

    return GestureDetector(
      onTap: () => _placePiece(position),
      child: Container(
        decoration: BoxDecoration(
          color: isLight ? Colors.grey.shade300 : Colors.grey.shade700,
          border: Border.all(color: Colors.black12),
        ),
        child: Center(
          child: piece != null
              ? Text(
                  piece.unicodeSymbol,
                  style: TextStyle(
                    fontSize: 36,
                    color: piece.color == PieceColor.white
                        ? const Color.fromARGB(
                            255,
                            127,
                            163,
                            197,
                          ) // Darker blue for white pieces
                        : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildPieceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Piece to Place:',
            style: TextStyle(fontWeight: FontWeight.bold),
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
              // Eraser
              ChoiceChip(
                label: const Icon(Icons.clear, size: 18),
                selected: selectedPieceType == null,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => selectedPieceType = null);
                  }
                },
                tooltip: 'Remove piece',
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      piece.unicodeSymbol,
                      style: TextStyle(
                        fontSize: 24,
                        color: selectedPieceColor == PieceColor.white
                            ? const Color.fromARGB(255, 127, 163, 197)
                            : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => selectedPieceType = type);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
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
