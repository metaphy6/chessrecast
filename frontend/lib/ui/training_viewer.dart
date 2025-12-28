import 'package:chessrecast/modes/modes_enum.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import '../board/utils/exporter.dart';

/// Training Game Viewer - Watch AI training games in real-time
/// Shows move-by-move playback of saved training games
class TrainingViewerScreen extends StatefulWidget {
  const TrainingViewerScreen({super.key});

  @override
  State<TrainingViewerScreen> createState() => _TrainingViewerScreenState();
}

class _TrainingViewerScreenState extends State<TrainingViewerScreen> {
  List<TrainingGame> games = [];
  TrainingGame? selectedGame;
  int currentMoveIndex = 0;
  bool isPlaying = false;
  ChessBoard? displayBoard;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    // Load games from training data directory
    // Path: ai/trainer/data/training_games/*.json
    try {
      final directory = Directory('../../ai/trainer/data/training_games');
      if (!await directory.exists()) {
        setState(() {
          games = [];
        });
        return;
      }

      final files = await directory
          .list()
          .where((entity) => entity.path.endsWith('.json'))
          .toList();

      final loadedGames = <TrainingGame>[];
      for (var file in files) {
        if (file is File) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content);
            loadedGames.add(TrainingGame.fromJson(json));
          } catch (e) {
            print('Error loading game ${file.path}: $e');
          }
        }
      }

      // Sort by iteration and game number
      loadedGames.sort((a, b) {
        final iterComp = a.iteration.compareTo(b.iteration);
        if (iterComp != 0) return iterComp;
        return a.gameNumber.compareTo(b.gameNumber);
      });

      setState(() {
        games = loadedGames;
      });
    } catch (e) {
      print('Error loading training games: $e');
    }
  }

  void _selectGame(TrainingGame game) {
    setState(() {
      selectedGame = game;
      currentMoveIndex = 0;
      isPlaying = false;
    });
    _updateBoard();
  }

  void _updateBoard() {
    if (selectedGame == null) return;

    // Reset board to starting position
    displayBoard = ChessBoard.initial(gameType: ModesEnum.mercenary);

    // Play moves up to current index
    for (
      int i = 0;
      i <= currentMoveIndex && i < selectedGame!.moves.length;
      i++
    ) {
      final move = selectedGame!.moves[i];
      try {
        // Parse move from UCI format (e.g., "e2e4")
        final from = Position.fromAlgebraic(move.from);
        final to = Position.fromAlgebraic(move.to);

        final piece = displayBoard!.getPieceAt(from);
        if (piece != null) {
          final chessMove = ChessMove.simple(
            from: from,
            to: to,
            piece: piece,
            capturedPiece: displayBoard!.getPieceAt(to),
          );
          displayBoard = displayBoard!.makeMove(chessMove);
        }
      } catch (e) {
        print('Error making move ${move.uci}: $e');
      }
    }

    setState(() {});
  }

  void _nextMove() {
    if (selectedGame == null) return;
    if (currentMoveIndex < selectedGame!.moves.length - 1) {
      setState(() {
        currentMoveIndex++;
      });
      _updateBoard();
    }
  }

  void _previousMove() {
    if (selectedGame == null) return;
    if (currentMoveIndex > 0) {
      setState(() {
        currentMoveIndex--;
      });
      _updateBoard();
    }
  }

  void _playPause() {
    setState(() {
      isPlaying = !isPlaying;
    });

    if (isPlaying) {
      _autoPlay();
    }
  }

  Future<void> _autoPlay() async {
    while (isPlaying &&
        currentMoveIndex < (selectedGame?.moves.length ?? 0) - 1) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!isPlaying) break;
      _nextMove();
    }
    setState(() {
      isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('🎮 AI Training Viewer'),
        elevation: 0,
      ),
      body: games.isEmpty
          ? _buildEmptyState()
          : Row(
              children: [
                // Left panel - Game list
                SizedBox(width: 300, child: _buildGameList()),
                // Divider
                Container(width: 1, color: Colors.white12),
                // Right panel - Game viewer
                Expanded(
                  child: selectedGame == null
                      ? _buildSelectGamePrompt()
                      : _buildGameViewer(),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 64, color: Colors.white30),
          const SizedBox(height: 16),
          const Text(
            'No Training Games Found',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start AI training to generate games',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadGames,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameList() {
    return Container(
      color: const Color(0xFF252538),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Text(
                  '${games.length} Games',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadGames,
                  color: Colors.white70,
                  iconSize: 20,
                ),
              ],
            ),
          ),
          // Game list
          Expanded(
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                final isSelected = selectedGame == game;
                return InkWell(
                  onTap: () => _selectGame(game),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                          : null,
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Iteration ${game.iteration}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Game #${game.gameNumber}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white60
                                    : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _resultIcon(game.result),
                            const SizedBox(width: 4),
                            Text(
                              game.result ?? 'In Progress',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white60
                                    : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${game.moves.length} moves',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white60
                                    : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultIcon(String? result) {
    if (result == null) {
      return const Icon(Icons.timelapse, size: 16, color: Colors.grey);
    }
    if (result == '1-0') {
      return const Icon(Icons.check_circle, size: 16, color: Colors.green);
    }
    if (result == '0-1') {
      return const Icon(Icons.cancel, size: 16, color: Colors.red);
    }
    return const Icon(Icons.handshake, size: 16, color: Colors.orange);
  }

  Widget _buildSelectGamePrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.touch_app, size: 64, color: Colors.white30),
          SizedBox(height: 16),
          Text(
            'Select a game to view',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildGameViewer() {
    final move = currentMoveIndex < selectedGame!.moves.length
        ? selectedGame!.moves[currentMoveIndex]
        : null;

    return Column(
      children: [
        // Game info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Text(
                'Iteration ${selectedGame!.iteration} - Game ${selectedGame!.gameNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _resultIcon(selectedGame!.result),
              const SizedBox(width: 8),
              Text(
                selectedGame!.result ?? 'In Progress',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        // Board and controls
        Expanded(
          child: Row(
            children: [
              // Chess board
              Expanded(
                flex: 2,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: displayBoard != null
                        ? _TrainingBoardDisplay(board: displayBoard!)
                        : const Center(
                            child: Text(
                              'Loading board...',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                  ),
                ),
              ),
              // Move info panel
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Move ${currentMoveIndex + 1} / ${selectedGame!.moves.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (move != null) ...[
                        const SizedBox(height: 16),
                        _buildMoveInfo('Move', move.san),
                        _buildMoveInfo('From', move.from),
                        _buildMoveInfo('To', move.to),
                        _buildMoveInfo('Turn', move.turn),
                        _buildMoveInfo('Value', move.value.toStringAsFixed(3)),
                        const SizedBox(height: 16),
                        const Text(
                          'Top 3 Moves:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...move.topMoves.map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text(
                                  m['move'],
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(m['probability'] * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Playback controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: currentMoveIndex > 0
                    ? () {
                        setState(() {
                          currentMoveIndex = 0;
                        });
                        _updateBoard();
                      }
                    : null,
                color: Colors.white70,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentMoveIndex > 0 ? _previousMove : null,
                color: Colors.white70,
              ),
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _playPause,
                color: const Color(0xFF7C3AED),
                iconSize: 32,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentMoveIndex < selectedGame!.moves.length - 1
                    ? _nextMove
                    : null,
                color: Colors.white70,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: currentMoveIndex < selectedGame!.moves.length - 1
                    ? () {
                        setState(() {
                          currentMoveIndex = selectedGame!.moves.length - 1;
                        });
                        _updateBoard();
                      }
                    : null,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoveInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class TrainingGame {
  final int iteration;
  final int gameNumber;
  final String mode;
  final String timestamp;
  final String? result;
  final List<GameMove> moves;

  TrainingGame({
    required this.iteration,
    required this.gameNumber,
    required this.mode,
    required this.timestamp,
    this.result,
    required this.moves,
  });

  factory TrainingGame.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>;
    final movesJson = json['moves'] as List;

    return TrainingGame(
      iteration: metadata['iteration'] as int,
      gameNumber: metadata['game_number'] as int,
      mode: metadata['mode'] as String? ?? 'classic',
      timestamp: metadata['timestamp'] as String,
      result: json['result'] as String?,
      moves: movesJson
          .map((m) => GameMove.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GameMove {
  final int number;
  final String uci;
  final String san;
  final String from;
  final String to;
  final String turn;
  final double value;
  final List<Map<String, dynamic>> topMoves;

  GameMove({
    required this.number,
    required this.uci,
    required this.san,
    required this.from,
    required this.to,
    required this.turn,
    required this.value,
    required this.topMoves,
  });

  factory GameMove.fromJson(Map<String, dynamic> json) {
    return GameMove(
      number: json['number'] as int,
      uci: json['move'] as String,
      san: json['san'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      turn: json['turn'] as String,
      value: (json['value'] as num).toDouble(),
      topMoves: (json['top_3_moves'] as List)
          .map((m) => m as Map<String, dynamic>)
          .toList(),
    );
  }
}

/// Custom board display for training viewer (read-only)
class _TrainingBoardDisplay extends StatelessWidget {
  final ChessBoard board;

  const _TrainingBoardDisplay({required this.board});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade800, width: 4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            color: Colors.brown.shade700,
            child: Column(
              children: List.generate(
                8,
                (row) => Expanded(
                  child: Row(
                    children: List.generate(8, (col) {
                      final pos = Position(7 - row, col);
                      final piece = board.getPieceAt(pos);
                      final isLight = (row + col) % 2 == 0;

                      return Expanded(
                        child: Container(
                          color: isLight
                              ? Colors.brown.shade300
                              : Colors.brown.shade600,
                          child: piece != null
                              ? Center(
                                  child: Text(
                                    _getPieceSymbol(piece),
                                    style: TextStyle(
                                      fontSize: 32,
                                      color: piece.color == PieceColor.white
                                          ? Colors.white
                                          : Colors.black,
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(1, 1),
                                          blurRadius: 2,
                                          color: piece.color == PieceColor.white
                                              ? Colors.black.withValues(
                                                  alpha: 0.5,
                                                )
                                              : Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getPieceSymbol(ChessPiece piece) {
    const whiteSymbols = {
      PieceType.king: '♔',
      PieceType.queen: '♕',
      PieceType.rook: '♖',
      PieceType.bishop: '♗',
      PieceType.knight: '♘',
      PieceType.pawn: '♙',
    };

    const blackSymbols = {
      PieceType.king: '♚',
      PieceType.queen: '♛',
      PieceType.rook: '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn: '♟',
    };

    return piece.color == PieceColor.white
        ? whiteSymbols[piece.type]!
        : blackSymbols[piece.type]!;
  }
}
