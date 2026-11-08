import '../domain/block_list.dart';
import '../domain/day.dart';
import '../domain/dungeon.dart';
import '../domain/engine.dart';
import '../domain/penalty.dart';
import '../domain/tasks.dart';
import 'codec.dart';
import 'log_entry.dart';

/// A timer task that is currently running.
class RunningTimer {
  const RunningTimer(this.taskId, this.startedAt);

  factory RunningTimer.fromJson(Map<String, Object?> j) =>
      RunningTimer(j['taskId'] as String, instantFromJson(j['startedAt']));

  final String taskId;
  final DateTime startedAt;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'startedAt': instantToJson(startedAt),
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
    this.systems,
    this.lockStartMinute,
    this.zoneOffsetMinutes,
    this.zoneId,
    this.pendingSleep,
    this.pendingLockStart,
    this.capReadAt,
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
    systems: j['systems'] == null
        ? null
        : systemsFromJson((j['systems'] as Map).cast<String, Object?>()),
    lockStartMinute: j['lockStartMinute'] as int?,
    zoneOffsetMinutes: j['zoneOffsetMinutes'] as int?,
    zoneId: j['zoneId'] as String?,
    pendingSleep: j['pendingSleep'] == null
        ? null
        : (
            dayFromJson((j['pendingSleep'] as Map)['from']),
            sleepFromJson(
              ((j['pendingSleep'] as Map)['sleep'] as Map)
                  .cast<String, Object?>(),
            ),
          ),
    capReadAt: j['capReadAt'] == null ? null : instantFromJson(j['capReadAt']),
    pendingLockStart: j['pendingLockStart'] == null
        ? null
        : (
            dayFromJson((j['pendingLockStart'] as Map)['from']),
            (j['pendingLockStart'] as Map)['minute'] as int,
          ),
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

  /// The user's System, rank, Gate and Dungeon. Null for games saved before
  /// Systems existed: those keep their own written objectives.
  final SystemsState? systems;

  /// Minutes after midnight when a penalty lock starts (the user's choice).
  /// Null in games from before the choice existed: their start is random.
  final int? lockStartMinute;

  /// The UTC offset, in minutes, of the zone the open day was issued in.
  /// A time-zone change can't move that day's deadline later.
  final int? zoneOffsetMinutes;

  /// The IANA zone the open day was issued in (null if unknown).
  final String? zoneId;

  /// A rest-period change waiting to take effect (from that day on).
  final (DayKey, SleepWindow)? pendingSleep;

  /// A lock-time change waiting to take effect (from that day on).
  final (DayKey, int)? pendingLockStart;

  /// When today's screen time was last read successfully during the day.
  final DateTime? capReadAt;

  /// The rest period in force on [day].
  SleepWindow sleepOn(DayKey day) {
    final p = pendingSleep;
    return p != null && !day.isBefore(p.$1) ? p.$2 : sleep;
  }

  /// The lock start in force on [day] (null: random, older games).
  int? lockStartOn(DayKey day) {
    final p = pendingLockStart;
    return p != null && !day.isBefore(p.$1) ? p.$2 : lockStartMinute;
  }

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
    'systems': systems == null ? null : systemsToJson(systems!),
    'lockStartMinute': lockStartMinute,
    'zoneOffsetMinutes': zoneOffsetMinutes,
    'zoneId': zoneId,
    'capReadAt': capReadAt == null ? null : instantToJson(capReadAt!),
    'pendingSleep': pendingSleep == null
        ? null
        : {
            'from': dayToJson(pendingSleep!.$1),
            'sleep': sleepToJson(pendingSleep!.$2),
          },
    'pendingLockStart': pendingLockStart == null
        ? null
        : {
            'from': dayToJson(pendingLockStart!.$1),
            'minute': pendingLockStart!.$2,
          },
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
    SystemsState? systems,
    int? lockStartMinute,
    int? zoneOffsetMinutes,
    String? zoneId,
    (DayKey, SleepWindow)? Function()? pendingSleep,
    (DayKey, int)? Function()? pendingLockStart,
    DateTime? capReadAt,
    List<LogEntry> newLogEntries = const [],
  }) => SavedGame(
    state: state ?? this.state,
    plan: plan ?? this.plan,
    progress: progress ?? this.progress,
    blockList: blockList ?? this.blockList,
    sleep: sleep ?? this.sleep,
    timer: timer != null ? timer() : this.timer,
    liveFrom: liveFrom,
    systems: systems ?? this.systems,
    lockStartMinute: lockStartMinute ?? this.lockStartMinute,
    zoneOffsetMinutes: zoneOffsetMinutes ?? this.zoneOffsetMinutes,
    zoneId: zoneId ?? this.zoneId,
    pendingSleep: pendingSleep != null ? pendingSleep() : this.pendingSleep,
    pendingLockStart: pendingLockStart != null
        ? pendingLockStart()
        : this.pendingLockStart,
    capReadAt: capReadAt ?? this.capReadAt,
    log: newLogEntries.isEmpty
        ? log
        : List.unmodifiable([...log, ...newLogEntries]),
  );
}
