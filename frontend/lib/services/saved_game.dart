import 'dart:convert';

class SavedGame {
  final String id;
  final DateTime timestamp;
  final String gameType;
  final String whiteLevel;
  final String blackLevel;
  final String result; // 'white', 'black', 'draw'
  final String resultReason; // 'checkmate', 'stalemate', 'draw'
  final List<String> moveLog;
  final String? startingFEN;
  final String? finalFEN;
  final List<String>? fenHistory;
  final int totalMoves;

  SavedGame({
    required this.id,
    required this.timestamp,
    required this.gameType,
    required this.whiteLevel,
    required this.blackLevel,
    required this.result,
    required this.resultReason,
    required this.moveLog,
    this.startingFEN,
    this.finalFEN,
    this.fenHistory,
    required this.totalMoves,
  });

  String get resultLabel {
    switch (result) {
      case 'white':
        return 'White wins ($resultReason)';
      case 'black':
        return 'Black wins ($resultReason)';
      default:
        return 'Draw ($resultReason)';
    }
  }

  String get summary =>
      '$whiteLevel vs $blackLevel · $totalMoves moves · $resultLabel';

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'gameType': gameType,
    'whiteLevel': whiteLevel,
    'blackLevel': blackLevel,
    'result': result,
    'resultReason': resultReason,
    'moveLog': moveLog,
    'startingFEN': startingFEN,
    'finalFEN': finalFEN,
    'fenHistory': fenHistory,
    'totalMoves': totalMoves,
  };

  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    gameType: json['gameType'] as String,
    whiteLevel: json['whiteLevel'] as String,
    blackLevel: json['blackLevel'] as String,
    result: json['result'] as String,
    resultReason: json['resultReason'] as String,
    moveLog: List<String>.from(json['moveLog'] as List),
    startingFEN: json['startingFEN'] as String?,
    finalFEN: json['finalFEN'] as String?,
    fenHistory: json['fenHistory'] != null
        ? List<String>.from(json['fenHistory'] as List)
        : null,
    totalMoves: json['totalMoves'] as int,
  );

  String toJsonString() => jsonEncode(toJson());

  factory SavedGame.fromJsonString(String s) =>
      SavedGame.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
