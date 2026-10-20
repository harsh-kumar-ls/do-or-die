import '../domain/engine.dart';

/// One line of the trial log. The log is append-only: nothing in the app can
/// edit or delete an entry.
class LogEntry {
  const LogEntry(this.at, this.type, [this.data = const {}]);

  factory LogEntry.fromJson(Map<String, Object?> j) => LogEntry(
    DateTime.parse(j['at'] as String),
    j['type'] as String,
    Map<String, Object?>.from(j['data'] as Map? ?? const {}),
  );

  final DateTime at;
  final String type;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'type': type,
    'data': data,
  };

  /// Converts an engine event into a log entry recorded at [at].
  factory LogEntry.fromEvent(DateTime at, GameEvent e) {
    final day = e.day.toString();
    return switch (e) {
      QuestCleared(:final xpGained) => LogEntry(at, 'quest_cleared', {
        'day': day,
        'xp': xpGained,
      }),
      QuestFailed(:final failedTaskIds) => LogEntry(at, 'quest_failed', {
        'day': day,
        'failedTaskIds': failedTaskIds,
      }),
      LevelUp(:final newLevel) => LogEntry(at, 'level_up', {
        'day': day,
        'level': newLevel,
      }),
      CarriedOver(:final pushups, :final squats) => LogEntry(
        at,
        'carried_over',
        {'day': day, 'pushups': pushups, 'squats': squats},
      ),
      PenaltyIssued(:final pushups, :final squats) => LogEntry(
        at,
        'penalty_issued',
        {'day': day, 'pushups': pushups, 'squats': squats},
      ),
      LockScheduled(:final window) => LogEntry(at, 'lock_scheduled', {
        'day': day,
        'start': window.start.toIso8601String(),
        'end': window.end.toIso8601String(),
        'clamped': window.clamped,
      }),
      LockMissed() => LogEntry(at, 'lock_missed', {'day': day}),
    };
  }
}
