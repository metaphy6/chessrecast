/// Time-control value class for P2P chess sessions.
///
/// §11.1 — Supported kinds sent in HELLO.time_control:
///   none          – correspondence (untimed)
///   sudden_death  – fixed bank, no increment
///   fischer       – bank + increment added after each move
///   bronstein     – bank + delay (unused portion of delay restored to bank)
///   byo_yomi      – main time + overtime periods
library time_control;

/// Available time-control kinds.
enum TcKind {
  none,
  suddenDeath,
  fischer,
  bronstein,
  byoYomi,
}

/// Validation result returned by [TimeControl.validate].
enum TcValidationResult {
  ok,
  invalidTimeControl,
}

/// Immutable value class describing a chess time control.
class TimeControl {
  final TcKind kind;

  /// Main bank in milliseconds (0 for [TcKind.none]).
  final int bankMs;

  /// Fischer increment per move in ms (only for [TcKind.fischer]).
  final int? incrementMs;

  /// Bronstein delay per move in ms (only for [TcKind.bronstein]).
  final int? delayMs;

  /// Duration of each overtime period in ms (only for [TcKind.byoYomi]).
  final int? overtimePeriodMs;

  /// Number of overtime periods (only for [TcKind.byoYomi]).
  final int? overtimePeriods;

  const TimeControl._({
    required this.kind,
    required this.bankMs,
    this.incrementMs,
    this.delayMs,
    this.overtimePeriodMs,
    this.overtimePeriods,
  });

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Correspondence (untimed) session.
  factory TimeControl.none() => const TimeControl._(
        kind: TcKind.none,
        bankMs: 0,
      );

  /// Sudden-death: [bankMs] fixed, no increment.
  factory TimeControl.suddenDeath({required int bankMs}) => TimeControl._(
        kind: TcKind.suddenDeath,
        bankMs: bankMs,
      );

  /// Fischer: [bankMs] + [incrementMs] added after each move.
  factory TimeControl.fischer({
    required int bankMs,
    required int incrementMs,
  }) =>
      TimeControl._(
        kind: TcKind.fischer,
        bankMs: bankMs,
        incrementMs: incrementMs,
      );

  /// Bronstein: [bankMs] + [delayMs] per move (unused delay restored to bank).
  factory TimeControl.bronstein({
    required int bankMs,
    required int delayMs,
  }) =>
      TimeControl._(
        kind: TcKind.bronstein,
        bankMs: bankMs,
        delayMs: delayMs,
      );

  /// Byo-yomi: [bankMs] main time, then [overtimePeriods] × [overtimePeriodMs].
  factory TimeControl.byoYomi({
    required int bankMs,
    required int overtimePeriodMs,
    required int overtimePeriods,
  }) =>
      TimeControl._(
        kind: TcKind.byoYomi,
        bankMs: bankMs,
        overtimePeriodMs: overtimePeriodMs,
        overtimePeriods: overtimePeriods,
      );

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  TcValidationResult validate() {
    switch (kind) {
      case TcKind.none:
        return TcValidationResult.ok;

      case TcKind.suddenDeath:
        if (bankMs <= 0) return TcValidationResult.invalidTimeControl;
        return TcValidationResult.ok;

      case TcKind.fischer:
        if (bankMs <= 0) return TcValidationResult.invalidTimeControl;
        if (incrementMs == null || incrementMs! < 0) {
          return TcValidationResult.invalidTimeControl;
        }
        return TcValidationResult.ok;

      case TcKind.bronstein:
        if (bankMs <= 0) return TcValidationResult.invalidTimeControl;
        if (delayMs == null || delayMs! < 0) {
          return TcValidationResult.invalidTimeControl;
        }
        return TcValidationResult.ok;

      case TcKind.byoYomi:
        if (bankMs < 0) return TcValidationResult.invalidTimeControl;
        if (overtimePeriodMs == null || overtimePeriodMs! <= 0) {
          return TcValidationResult.invalidTimeControl;
        }
        if (overtimePeriods == null || overtimePeriods! <= 0) {
          return TcValidationResult.invalidTimeControl;
        }
        return TcValidationResult.ok;
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'kind': kind.name,
      'bank_ms': bankMs,
      if (incrementMs != null) 'increment_ms': incrementMs,
      if (delayMs != null) 'delay_ms': delayMs,
      if (overtimePeriodMs != null) 'overtime_period_ms': overtimePeriodMs,
      if (overtimePeriods != null) 'overtime_periods': overtimePeriods,
    };
  }

  factory TimeControl.fromMap(Map<String, dynamic> m) {
    final kindStr = m['kind'] as String? ?? '';
    final kind = TcKind.values.firstWhere(
      (k) => k.name == kindStr,
      orElse: () => throw ArgumentError('Unknown TcKind: $kindStr'),
    );
    return TimeControl._(
      kind: kind,
      bankMs: (m['bank_ms'] as num?)?.toInt() ?? 0,
      incrementMs: (m['increment_ms'] as num?)?.toInt(),
      delayMs: (m['delay_ms'] as num?)?.toInt(),
      overtimePeriodMs: (m['overtime_period_ms'] as num?)?.toInt(),
      overtimePeriods: (m['overtime_periods'] as num?)?.toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeControl &&
        other.kind == kind &&
        other.bankMs == bankMs &&
        other.incrementMs == incrementMs &&
        other.delayMs == delayMs &&
        other.overtimePeriodMs == overtimePeriodMs &&
        other.overtimePeriods == overtimePeriods;
  }

  @override
  int get hashCode => Object.hash(
        kind,
        bankMs,
        incrementMs,
        delayMs,
        overtimePeriodMs,
        overtimePeriods,
      );

  @override
  String toString() => 'TimeControl(kind:${kind.name}, bankMs:$bankMs)';
}
