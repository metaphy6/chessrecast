import '../../board/board.dart';
import '../../board/moves/move.dart';
import '../../board/items/piece_color.dart';
import '../../services/ai_service.dart';

/// AI Player that uses neural network for move selection
/// Distinct from Bot which uses rule-based algorithms
class AIPlayer {
  final String name;
  final PieceColor color;
  final int eloRating;
  final int thinkingDelayMs;
  final AIService _aiService;

  AIPlayer({
    required this.name,
    required this.color,
    this.eloRating = 1800,
    this.thinkingDelayMs = 1000,
  }) : _aiService = AIService.instance;

  /// Get the best move from the AI
  Future<ChessMove?> getMove(ChessBoard board) async {
    // Add thinking delay for realism
    await Future.delayed(Duration(milliseconds: thinkingDelayMs));

    try {
      return await _aiService.getBestMove(
        board,
        thinkingTimeMs: thinkingDelayMs,
      );
    } catch (e) {
      print('❌ AI Player error: $e');
      return null;
    }
  }

  @override
  String toString() => '$name (AI, ELO: $eloRating)';
}

/// AI Player Types
enum AIPlayerType {
  mercenary1800('Mercenary AI', 1800, 'Trained on Mercenary mode, 1800 ELO')
  // Future: Add more specialized AIs
  // classic2000('Classic AI', 2000, 'Trained on Classic chess, 2000 ELO'),
  // truce1500('Truce AI', 1500, 'Specialized for Truce mode, 1500 ELO'),
  ;

  final String displayName;
  final int eloRating;
  final String description;

  const AIPlayerType(this.displayName, this.eloRating, this.description);

  /// Create an AI player instance
  AIPlayer createPlayer(PieceColor color, {int? thinkingDelayMs}) {
    return AIPlayer(
      name: displayName,
      color: color,
      eloRating: eloRating,
      thinkingDelayMs: thinkingDelayMs ?? 1000,
    );
  }
}
