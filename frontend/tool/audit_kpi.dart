/// Shared helpers for parsing and aggregating king-policy KPI lines emitted
/// by all engine audit tools (via [KingPolicyMetrics]).
///
/// Every engine audit emits a line of the form:
///   King-policy KPIs: earlyKingMoveCount(<=ply12)=N
///       castlingRightLossByVoluntaryKingMove=N
///       castledByPly[w=X,b=X]
///       kingExposureIndex(avg)=N.NN
///
/// Batch tools use [AuditKpiSnapshot.fromReport] to parse it from each game
/// report and [AuditKpiAggregate.fromSnapshots] to produce a summary line.
final RegExp kpiLinePattern = RegExp(
  r'^King-policy KPIs: earlyKingMoveCount\(<=ply12\)=(\d+) '
  r'castlingRightLossByVoluntaryKingMove=(\d+) '
  r'castledByPly\[w=([^,]+),b=([^\]]+)\] '
  r'kingExposureIndex\(avg\)=([0-9]+\.[0-9]+)',
  multiLine: true,
);

class AuditKpiSnapshot {
  final int earlyKingMoveCount;
  final int castlingRightLossCount;
  final bool whiteCastled;
  final bool blackCastled;
  final double kingExposureIndex;

  const AuditKpiSnapshot({
    required this.earlyKingMoveCount,
    required this.castlingRightLossCount,
    required this.whiteCastled,
    required this.blackCastled,
    required this.kingExposureIndex,
  });

  factory AuditKpiSnapshot.zero() => const AuditKpiSnapshot(
    earlyKingMoveCount: 0,
    castlingRightLossCount: 0,
    whiteCastled: false,
    blackCastled: false,
    kingExposureIndex: 0.0,
  );

  factory AuditKpiSnapshot.fromReport(String report) {
    final m = kpiLinePattern.firstMatch(report);
    if (m == null) return AuditKpiSnapshot.zero();
    return AuditKpiSnapshot(
      earlyKingMoveCount: int.parse(m.group(1)!),
      castlingRightLossCount: int.parse(m.group(2)!),
      whiteCastled: m.group(3)! != 'never',
      blackCastled: m.group(4)! != 'never',
      kingExposureIndex: double.parse(m.group(5)!),
    );
  }
}

class AuditKpiAggregate {
  final int totalEarlyKingMoves;
  final int totalCastlingRightLosses;
  final int whiteCastledGames;
  final int blackCastledGames;
  final int totalGames;
  final double avgKingExposureIndex;

  const AuditKpiAggregate({
    required this.totalEarlyKingMoves,
    required this.totalCastlingRightLosses,
    required this.whiteCastledGames,
    required this.blackCastledGames,
    required this.totalGames,
    required this.avgKingExposureIndex,
  });

  factory AuditKpiAggregate.fromSnapshots(List<AuditKpiSnapshot> snapshots) {
    if (snapshots.isEmpty) {
      return const AuditKpiAggregate(
        totalEarlyKingMoves: 0,
        totalCastlingRightLosses: 0,
        whiteCastledGames: 0,
        blackCastledGames: 0,
        totalGames: 0,
        avgKingExposureIndex: 0.0,
      );
    }
    return AuditKpiAggregate(
      totalEarlyKingMoves: snapshots.fold(
        0,
        (s, k) => s + k.earlyKingMoveCount,
      ),
      totalCastlingRightLosses: snapshots.fold(
        0,
        (s, k) => s + k.castlingRightLossCount,
      ),
      whiteCastledGames: snapshots.where((k) => k.whiteCastled).length,
      blackCastledGames: snapshots.where((k) => k.blackCastled).length,
      totalGames: snapshots.length,
      avgKingExposureIndex:
          snapshots.fold(0.0, (s, k) => s + k.kingExposureIndex) /
          snapshots.length,
    );
  }

  String toSummaryLine() {
    return 'KPI aggregate: earlyKingMoves=$totalEarlyKingMoves '
        'castlingRightLosses=$totalCastlingRightLosses '
        'castled[w=$whiteCastledGames/$totalGames,'
        'b=$blackCastledGames/$totalGames] '
        'kingExposureIndex(avg)=${avgKingExposureIndex.toStringAsFixed(2)}';
  }
}
