import '../domain/dungeon.dart';
import 'codec.dart';
import '../domain/engine.dart';

/// One line of the trial log. The log is append-only: nothing in the app can
/// edit or delete an entry.
class LogEntry {
  const LogEntry(this.at, this.type, [this.data = const {}]);

  factory LogEntry.fromJson(Map<String, Object?> j) => LogEntry(
    instantFromJson(j['at']),
    j['type'] as String,
    Map<String, Object?>.from(j['data'] as Map? ?? const {}),
  );

  final DateTime at;
  final String type;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    'at': instantToJson(at),
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
      PenaltyExpired(:final primary, :final secondary, :final kind) => LogEntry(
        at,
        'penalty_expired',
        {
          'day': day,
          'kind': kind.name,
          'primary': primary,
          'secondary': secondary,
        },
      ),
      PenaltyIssued(
        :final primary,
        :final secondary,
        :final kind,
        :final enforced,
      ) =>
        LogEntry(at, 'penalty_issued', {
          'day': day,
          'kind': kind.name,
          'primary': primary,
          'secondary': secondary,
          'enforced': enforced,
        }),
      LockScheduled(:final window, :final enforced) => LogEntry(
        at,
        'lock_scheduled',
        {
          'day': day,
          'start': window.start.toIso8601String(),
          'end': window.end.toIso8601String(),
          'clamped': window.clamped,
          'enforced': enforced,
        },
      ),
      LockMissed() => LogEntry(at, 'lock_missed', {'day': day}),
    };
  }

  /// Converts a System event into a log entry recorded at [at].
  factory LogEntry.fromSystemEvent(DateTime at, SystemEvent e) {
    final day = e.day.toString();
    return switch (e) {
      GateOpened(:final gate) => LogEntry(at, 'gate_opened', {
        'day': day,
        'from': gate.from.name,
        'expiresAt': gate.expiresAt.toIso8601String(),
      }),
      GateExpired() => LogEntry(at, 'gate_expired', {'day': day}),
      DungeonEntered(:final dungeon) => LogEntry(at, 'dungeon_entered', {
        'day': day,
        'from': dungeon.from.name,
        'firstFloor': dungeon.firstFloor.toString(),
      }),
      FloorCleared(:final floor) => LogEntry(at, 'floor_cleared', {
        'day': day,
        'floor': floor,
      }),
      DungeonCleared(:final newRank, :final title) => LogEntry(
        at,
        'dungeon_cleared',
        {'day': day, 'newRank': newRank.name, 'title': title},
      ),
      DungeonFailed(:final floor) => LogEntry(at, 'dungeon_failed', {
        'day': day,
        'floor': floor,
      }),
      SystemCompleted(:final system) => LogEntry(at, 'system_completed', {
        'day': day,
        'system': system.name,
      }),
    };
  }
}
