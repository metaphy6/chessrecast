import '../../../board/utils/exporter.dart';

/// Opening book with common opening moves
class OpeningBook {
  /// Check if position is in opening book and return a good move
  static ChessMove? getBookMove(ChessBoard board, List<ChessMove> validMoves) {
    // Only use opening book in first 10 moves
    if (board.moveHistory.length > 10) return null;

    final key = _getBoardKey(board);
    final bookMoves = _openingBook[key];

    if (bookMoves == null || bookMoves.isEmpty) return null;

    // Find matching moves from valid moves
    final matchingMoves = validMoves.where((move) {
      final moveNotation = _getMoveNotation(move);
      return bookMoves.contains(moveNotation);
    }).toList();

    if (matchingMoves.isEmpty) return null;

    // Return first matching book move (could randomize later)
    return matchingMoves.first;
  }

  /// Get a simple board key (simplified FEN)
  static String _getBoardKey(ChessBoard board) {
    // Simple position encoding - just piece positions
    final buffer = StringBuffer();
    for (int row = 7; row >= 0; row--) {
      int emptyCount = 0;
      for (int col = 0; col < 8; col++) {
        final piece = board.getPieceAt(Position(row, col));
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            buffer.write(emptyCount);
            emptyCount = 0;
          }
          buffer.write(piece.fenSymbol);
        }
      }
      if (emptyCount > 0) buffer.write(emptyCount);
      if (row > 0) buffer.write('/');
    }
    buffer.write(' ${board.currentPlayer == PieceColor.white ? 'w' : 'b'}');
    return buffer.toString();
  }

  /// Get move notation (simplified algebraic)
  static String _getMoveNotation(ChessMove move) {
    return '${move.from.algebraic}${move.to.algebraic}';
  }

  /// Opening book database
  static final Map<String, List<String>> _openingBook = {
    // Starting position - popular first moves
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w': [
      'e2e4', // King's Pawn
      'd2d4', // Queen's Pawn
      'g1f3', // Reti
      'c2c4', // English
    ],

    // After 1.e4
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b': [
      'e7e5', // Open game
      'c7c5', // Sicilian
      'e7e6', // French
      'c7c6', // Caro-Kann
    ],

    // After 1.e4 e5
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w': [
      'g1f3', // King's Knight
      'f2f4', // King's Gambit
      'b1c3', // Vienna
    ],

    // After 1.e4 e5 2.Nf3
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b': [
      'b8c6', // Most common
      'g8f6', // Petrov
      'd7d6', // Philidor
    ],

    // After 1.e4 e5 2.Nf3 Nc6
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w': [
      'f1b5', // Ruy Lopez
      'f1c4', // Italian
      'd2d4', // Scotch
    ],

    // After 1.d4
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b': [
      'd7d5', // Closed game
      'g8f6', // Indian defenses
      'e7e6', // French-style
    ],

    // After 1.d4 d5
    'rnbqkbnr/ppp1pppp/8/3p4/3P4/8/PPP1PPPP/RNBQKBNR w': [
      'c2c4', // Queen's Gambit
      'g1f3', // Quiet
      'e2e3', // Colle
    ],

    // After 1.d4 Nf6
    'rnbqkb1r/pppppppp/5n2/8/3P4/8/PPP1PPPP/RNBQKBNR w': [
      'c2c4', // Most common
      'g1f3', // Quiet
      'b1c3', // Veresov
    ],

    // After 1.d4 Nf6 2.c4
    'rnbqkb1r/pppppppp/5n2/8/2PP4/8/PP2PPPP/RNBQKBNR b': [
      'e7e6', // Nimzo/Queen's Indian prep
      'g7g6', // King's Indian
      'd7d5', // Queen's Gambit Declined
    ],

    // After 1.e4 c5 (Sicilian)
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w': [
      'g1f3', // Open Sicilian
      'b1c3', // Closed Sicilian
      'c2c3', // Alapin
    ],

    // After 1.e4 c5 2.Nf3
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b': [
      'd7d6', // Dragon/Najdorf prep
      'b8c6', // Old Sicilian
      'e7e6', // French-Sicilian
    ],

    // After 1.e4 c5 2.Nf3 d6
    'rnbqkbnr/pp2pppp/3p4/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R w': [
      'd2d4', // Open Sicilian
      'f1c4', // Closed
    ],

    // After 1.e4 c5 2.Nf3 d6 3.d4
    'rnbqkbnr/pp2pppp/3p4/2p5/3PP3/5N2/PPP2PPP/RNBQKB1R b': [
      'c5d4', // Accept pawn
    ],

    // After 1.e4 c5 2.Nf3 d6 3.d4 cxd4
    'rnbqkbnr/pp2pppp/3p4/8/3pP3/5N2/PPP2PPP/RNBQKB1R w': [
      'f3d4', // Recapture
    ],
  };
}
