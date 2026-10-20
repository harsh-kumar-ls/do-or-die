import '../domain/block_list.dart';
import '../domain/day.dart';
import '../domain/engine.dart';
import '../domain/penalty.dart';
import '../domain/tasks.dart';
import 'codec.dart';
import 'log_entry.dart';

/// A timer task that is currently running.
class RunningTimer {
  const RunningTimer(this.taskId, this.startedAt);

  factory RunningTimer.fromJson(Map<String, Object?> j) => RunningTimer(
    j['taskId'] as String,
    DateTime.parse(j['startedAt'] as String),
  );

  final String taskId;
  final DateTime startedAt;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'startedAt': startedAt.toIso8601String(),
  };
}

/// Everything the app saves, in one document so it is written atomically.
class SavedGame {
  const SavedGame({
    required this.state,
    required this.plan,
    required this.progress,
    required this.blockList,
    required this.sleep,
    required this.log,
    this.timer,
    this.liveFrom,
  });

  factory SavedGame.fromJson(Map<String, Object?> j) => SavedGame(
    state: stateFromJson((j['state'] as Map).cast<String, Object?>()),
    plan: planFromJson((j['plan'] as Map).cast<String, Object?>()),
    progress: progressFromJson((j['progress'] as Map).cast<String, Object?>()),
    blockList: blockListFromJson(
      (j['blockList'] as Map).cast<String, Object?>(),
    ),
    sleep: sleepFromJson((j['sleep'] as Map).cast<String, Object?>()),
    log: List.unmodifiable([
      for (final e in (j['log'] as List).cast<Map>())
        LogEntry.fromJson(e.cast<String, Object?>()),
    ]),
    timer: j['timer'] == null
        ? null
        : RunningTimer.fromJson((j['timer'] as Map).cast<String, Object?>()),
    liveFrom: j['liveFrom'] == null ? null : dayFromJson(j['liveFrom']),
  );

  static const schemaVersion = 1;

  final GameState state;
  final QuestPlan plan;
  final Map<DayKey, DayProgress> progress;
  final BlockList blockList;
  final SleepWindow sleep;

  /// Append-only trial log.
  final List<LogEntry> log;

  /// The timer task currently running, if any.
  final RunningTimer? timer;

  /// The first day whose failure is really enforced. Failures before it are
  /// a dry run: judged, shown and logged, but nothing is owed or locked.
  /// Null (games saved before dry-run mode existed) means always enforced.
  final DayKey? liveFrom;

  /// Whether a failure on [day] brings a real penalty.
  bool isEnforced(DayKey day) => liveFrom == null || !day.isBefore(liveFrom!);

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'state': stateToJson(state),
    'plan': planToJson(plan),
    'progress': progressToJson(progress),
    'blockList': blockListToJson(blockList),
    'sleep': sleepToJson(sleep),
    'log': [for (final e in log) e.toJson()],
    'timer': timer?.toJson(),
    'liveFrom': liveFrom == null ? null : dayToJson(liveFrom!),
  };

  /// Returns a copy. [newLogEntries] are appended; existing entries can't be
  /// replaced through this API.
  SavedGame copyWith({
    GameState? state,
    QuestPlan? plan,
    Map<DayKey, DayProgress>? progress,
    BlockList? blockList,
    SleepWindow? sleep,
    RunningTimer? Function()? timer,
    List<LogEntry> newLogEntries = const [],
  }) => SavedGame(
    state: state ?? this.state,
    plan: plan ?? this.plan,
    progress: progress ?? this.progress,
    blockList: blockList ?? this.blockList,
    sleep: sleep ?? this.sleep,
    timer: timer != null ? timer() : this.timer,
    liveFrom: liveFrom,
    log: newLogEntries.isEmpty
        ? log
        : List.unmodifiable([...log, ...newLogEntries]),
  );
}
