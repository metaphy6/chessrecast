import '../board/moves/move.dart';

/// Result returned by an engine search.
class SearchResult {
  final ChessMove? bestMove;
  final int score;
  final int depth;
  final int nodesSearched;

  const SearchResult({
    this.bestMove,
    required this.score,
    required this.depth,
    required this.nodesSearched,
  });

  @override
  String toString() =>
      'depth=$depth score=$score nodes=$nodesSearched move=$bestMove';
}
