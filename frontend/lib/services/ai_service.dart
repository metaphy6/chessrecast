import 'dart:math' as math;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../board/board.dart';
import '../board/moves/move.dart';
import '../board/moves/generation.dart';
import '../board/pieces/piece_color.dart';

/// AI Player using TensorFlow Lite model for inference
/// Supports custom game mods including Mercenary
class AIService {
  static AIService? _instance;
  Interpreter? _interpreter;
  bool _isInitialized = false;

  /// AI difficulty level (used for move selection strategy)
  /// 1800: Strong intermediate player
  final int eloRating = 1800;

  AIService._();

  /// Get singleton instance
  static AIService get instance {
    _instance ??= AIService._();
    return _instance!;
  }

  /// Initialize the AI model
  Future<void> initialize({
    String modelPath = 'assets/models/mercenary_1800.tflite',
  }) async {
    if (_isInitialized) return;

    try {
      print('🤖 Initializing AI Service (ELO: $eloRating)...');

      // Load TFLite model
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);

      print('   ✓ Model loaded: $modelPath');
      print('   ✓ Input shape: ${_interpreter!.getInputTensors()}');
      print('   ✓ Output shape: ${_interpreter!.getOutputTensors()}');

      _isInitialized = true;
      print('✓ AI Service ready!');
    } catch (e) {
      print('⚠️ AI model not available: $e');
      print('   To use AI features, train the model first:');
      print('   cd ai && docker compose -f docker-compose.mercenary.yml up');
      // Don't rethrow - allow app to start without AI
      _isInitialized = false;
    }
  }

  /// Get the best move for the current board position
  Future<ChessMove?> getBestMove(
    ChessBoard board, {
    int thinkingTimeMs = 1000,
  }) async {
    if (!_isInitialized) {
      throw StateError('AI Service not initialized. Call initialize() first.');
    }

    final startTime = DateTime.now();

    try {
      // Convert board to tensor input
      final inputTensor = _boardToTensor(board);

      // Prepare output buffers
      // Policy: 4096 possible moves (from_square * to_square = 64 * 64)
      // Value: Single float [-1, 1] representing position evaluation
      final policyOutput = List.filled(4096, 0.0).reshape([1, 4096]);
      final valueOutput = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _interpreter!.runForMultipleInputs(
        [inputTensor],
        {0: policyOutput, 1: valueOutput},
      );

      // Get all legal moves from current board
      final legalMoves = _getAllLegalMoves(board);

      if (legalMoves.isEmpty) {
        return null; // No legal moves (game over)
      }

      // Score each legal move using policy network
      final moveScores = <ChessMove, double>{};
      for (final move in legalMoves) {
        final moveIndex = _moveToIndex(move);
        if (moveIndex >= 0 && moveIndex < 4096) {
          moveScores[move] = policyOutput[0][moveIndex];
        }
      }

      // Select best move (or use temperature for variety)
      final bestMove = _selectMove(moveScores, temperature: 0.1);

      final elapsed = DateTime.now().difference(startTime);
      print('🤖 AI move calculated in ${elapsed.inMilliseconds}ms');

      return bestMove;
    } catch (e) {
      print('❌ AI inference error: $e');
      return null;
    }
  }

  /// Convert ChessBoard to 8x8x12 tensor
  /// 12 channels: 6 piece types × 2 colors
  Float32List _boardToTensor(ChessBoard board) {
    final tensor = Float32List(1 * 12 * 8 * 8);

    // Piece type to channel mapping
    const pieceTypeToChannel = {
      'pawn': 0,
      'knight': 1,
      'bishop': 2,
      'rook': 3,
      'queen': 4,
      'king': 5,
    };

    for (final piece in board.pieces) {
      final row = piece.position.row;
      final col = piece.position.col;
      final pieceType = piece.type.name;

      if (pieceTypeToChannel.containsKey(pieceType)) {
        var channel = pieceTypeToChannel[pieceType]!;

        // Black pieces: channels 6-11
        if (piece.color == PieceColor.black) {
          channel += 6;
        }

        // Tensor layout: [batch, channels, height, width]
        // Flatten index: batch * (C*H*W) + channel * (H*W) + row * W + col
        final index = channel * 64 + row * 8 + col;
        tensor[index] = 1.0;
      }
    }

    return tensor;
  }

  /// Convert move to policy network index
  /// Index = from_square * 64 + to_square
  int _moveToIndex(ChessMove move) {
    final fromIdx = move.from.row * 8 + move.from.col;
    final toIdx = move.to.row * 8 + move.to.col;
    return fromIdx * 64 + toIdx;
  }

  /// Select move from scored moves using temperature
  /// Temperature 0.0 = always best, 1.0 = proportional to scores
  ChessMove _selectMove(
    Map<ChessMove, double> moveScores, {
    double temperature = 0.1,
  }) {
    if (moveScores.isEmpty) {
      throw StateError('No moves to select from');
    }

    if (temperature < 0.01) {
      // Deterministic: pick highest score
      var bestMove = moveScores.keys.first;
      var bestScore = moveScores[bestMove]!;

      for (final entry in moveScores.entries) {
        if (entry.value > bestScore) {
          bestScore = entry.value;
          bestMove = entry.key;
        }
      }

      return bestMove;
    }

    // Temperature-based sampling
    final moves = moveScores.keys.toList();
    final scores = moveScores.values.toList();

    // Apply temperature and softmax
    final expScores = scores.map((s) => math.exp(s / temperature)).toList();
    final sumExp = expScores.reduce((a, b) => a + b);
    final probs = expScores.map((e) => e / sumExp).toList();

    // Sample from distribution
    final random = math.Random();
    final r = random.nextDouble();
    var cumProb = 0.0;

    for (int i = 0; i < moves.length; i++) {
      cumProb += probs[i];
      if (r < cumProb) {
        return moves[i];
      }
    }

    return moves.last;
  }

  /// Get all legal moves for current board state
  List<ChessMove> _getAllLegalMoves(ChessBoard board) {
    final allMoves = <ChessMove>[];
    for (final piece in board.pieces) {
      if (piece.color == board.currentPlayer) {
        final moves = board.getValidMovesFor(piece.position);
        allMoves.addAll(moves);
      }
    }
    return allMoves;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
