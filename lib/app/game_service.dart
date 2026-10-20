import 'dart:convert';
import 'dart:math';

import '../data/game_store.dart';
import '../data/log_entry.dart';
import '../data/saved_game.dart';
import '../domain/block_list.dart';
import '../domain/clock.dart';
import '../domain/day.dart';
import '../domain/engine.dart';
import '../domain/penalty.dart';
import '../domain/progression.dart';
import '../domain/tasks.dart';
import '../data/codec.dart';

/// The single entry point the UI uses. Every change is logged and saved.
class GameService {
  GameService._(
    this._store,
    this._clock,
    this._random,
    this.engine,
    this._game,
  );

  final GameStore _store;
  final Clock _clock;
  final Random _random;
  final QuestEngine engine;
  SavedGame _game;

  SavedGame get game => _game;
  GameState get state => _game.state;
  DayKey get today => DayKey.fromDateTime(_clock.now());

  /// The current time on the game's clock (network-corrected on Android).
  DateTime get now => _clock.now();
  List<TaskDefinition> get todaysTasks => _game.plan.tasksFor(today);
  DayProgress get todaysProgress => _game.progress[today] ?? const {};
  Set<String> get blockedToday => _game.blockList.packagesOn(today);

  /// Loads a saved game, or returns null if none exists yet.
  static Future<GameService?> load({
    required GameStore store,
    Clock clock = const SystemClock(),
    Random? random,
    QuestEngine? engine,
  }) async {
    final saved = await store.load();
    if (saved == null) return null;
    final service = GameService._(
      store,
      clock,
      random ?? Random(),
      engine ?? QuestEngine(),
      saved,
    );
    await service.tick();
    return service;
  }

  /// Starts a new game from onboarding choices.
  ///
  /// With [dryRunDays] > 0, failures on the first that-many days are a dry
  /// run: judged, shown and logged, but nothing is owed or locked.
  static Future<GameService> start({
    required GameStore store,
    required List<TaskDefinition> tasks,
    required Set<String> blockedPackages,
    SleepWindow sleep = const SleepWindow(),
    int dryRunDays = 0,
    Clock clock = const SystemClock(),
    Random? random,
    QuestEngine? engine,
  }) async {
    final now = clock.now();
    final day = DayKey.fromDateTime(now);
    final liveFrom = dryRunDays > 0 ? day.addDays(dryRunDays) : null;
    final game = SavedGame(
      state: GameState.start(day),
      plan: QuestPlan.initial(day, tasks),
      progress: const {},
      blockList: BlockList.initial(day, blockedPackages),
      sleep: sleep,
      liveFrom: liveFrom,
      log: List.unmodifiable([
        LogEntry(now, 'game_started', {
          'day': day.toString(),
          'tasks': [for (final t in tasks) taskToJson(t)],
          'blocked': blockedPackages.toList()..sort(),
          'sleep': {'start': sleep.startMinute, 'end': sleep.endMinute},
          'liveFrom': liveFrom?.toString(),
        }),
      ]),
    );
    await store.save(game);
    return GameService._(
      store,
      clock,
      random ?? Random(),
      engine ?? QuestEngine(),
      game,
    );
  }

  /// Day of the trial, starting at 1 on the day the game began.
  int get trialDay => state.startDay.daysUntil(today) + 1;

  /// The first day whose failure is enforced; null if always enforced.
  DayKey? get liveFrom => _game.liveFrom;

  /// Whether failing today would only be a dry run.
  bool get isDryRunToday => !_game.isEnforced(today);

  /// A penalty is owed, scheduled or running today.
  bool get penaltyInEffect {
    final debt = state.debt;
    final owes = debt != null && debt.dueDay == today && !debt.isPaid;
    final lock = state.lock;
    final locked = lock != null && lock.end.isAfter(now);
    return owes || locked;
  }

  /// Archives this game and starts a fresh trial with the same objectives,
  /// apps and sleep window. Refused while a penalty is in effect, so a
  /// restart can never be used to escape one. Returns null when refused.
  Future<GameService?> restartTrial({int dryRunDays = 3}) async {
    if (penaltyInEffect) return null;
    if (_game.timer != null) await stopTimer();
    final archived = _game.copyWith(
      newLogEntries: [LogEntry(now, 'trial_restarted')],
    );
    await _store.archive(archived);
    return start(
      store: _store,
      tasks: todaysTasks,
      blockedPackages: blockedToday,
      sleep: _game.sleep,
      dryRunDays: dryRunDays,
      clock: _clock,
      random: _random,
      engine: engine,
    );
  }

  /// Judges any finished days. Call on app start, on resume, and at midnight.
  Future<List<GameEvent>> tick() async {
    final now = _clock.now();
    // A timer left running past midnight counts only up to midnight, and
    // must be credited before that day is judged.
    final timer = _game.timer;
    if (timer != null &&
        DayKey.fromDateTime(timer.startedAt)
            .isBefore(DayKey.fromDateTime(now))) {
      await _commit(_withTimerCredited(now));
    }
    final result = engine.closeDaysBefore(
      state: _game.state,
      today: DayKey.fromDateTime(now),
      plan: _game.plan,
      progressFor: (d) => _game.progress[d] ?? const {},
      sleep: _game.sleep,
      random: _random,
      now: now,
      isEnforced: _game.isEnforced,
    );
    if (result.events.isEmpty) return const [];
    await _commit(
      _game.copyWith(
        state: result.state,
        newLogEntries: [
          for (final e in result.events) LogEntry.fromEvent(now, e),
        ],
      ),
    );
    return result.events;
  }

  /// Sets today's progress on [taskId]. Ignored for unknown tasks.
  Future<void> setProgress(String taskId, int value) async {
    await tick();
    final day = today;
    if (!_game.state.isOpen(day)) return;
    if (!todaysTasks.any((t) => t.id == taskId)) return;
    final clamped = max(0, value);
    final dayProgress = {...todaysProgress, taskId: clamped};
    await _commit(
      _game.copyWith(
        progress: {..._game.progress, day: dayProgress},
        newLogEntries: [
          LogEntry(_clock.now(), 'progress', {
            'day': day.toString(),
            'taskId': taskId,
            'value': clamped,
          }),
        ],
      ),
    );
  }

  Future<void> addProgress(String taskId, int delta) =>
      setProgress(taskId, (todaysProgress[taskId] ?? 0) + delta);

  bool isTimerRunning(String taskId) => _game.timer?.taskId == taskId;

  /// Today's progress, including time on a timer that is still running
  /// (seconds for timer tasks).
  int liveProgress(String taskId) {
    final saved = todaysProgress[taskId] ?? 0;
    final timer = _game.timer;
    if (timer == null || timer.taskId != taskId) return saved;
    if (DayKey.fromDateTime(timer.startedAt) != today) return saved;
    return saved + max(0, _clock.now().difference(timer.startedAt).inSeconds);
  }

  /// Seconds elapsed on the running timer for [taskId], for a live display.
  int runningSeconds(String taskId) {
    final timer = _game.timer;
    if (timer == null || timer.taskId != taskId) return 0;
    return max(0, _clock.now().difference(timer.startedAt).inSeconds);
  }

  Future<void> startTimer(String taskId) async {
    await tick();
    final task = todaysTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.type != TaskType.timer) return;
    if (!_game.state.isOpen(today)) return;
    if (_game.timer?.taskId == taskId) return;
    var next = _game.timer == null ? _game : _withTimerCredited(_clock.now());
    final now = _clock.now();
    next = next.copyWith(
      timer: () => RunningTimer(taskId, now),
      newLogEntries: [
        LogEntry(now, 'timer_started', {
          'day': today.toString(),
          'taskId': taskId,
        }),
      ],
    );
    await _commit(next);
  }

  Future<void> stopTimer() async {
    if (_game.timer == null) return;
    await _commit(_withTimerCredited(_clock.now()));
    await tick();
  }

  /// Stops the running timer and adds its seconds to the day it started,
  /// counting no further than that day's midnight.
  SavedGame _withTimerCredited(DateTime now) {
    final timer = _game.timer!;
    final day = DayKey.fromDateTime(timer.startedAt);
    final midnight = day.addDays(1).at(0);
    final end = now.isAfter(midnight) ? midnight : now;
    final seconds = max(0, end.difference(timer.startedAt).inSeconds);
    final credited = _game.state.isOpen(day);
    final dayProgress = _game.progress[day] ?? const {};
    return _game.copyWith(
      timer: () => null,
      progress: credited
          ? {
              ..._game.progress,
              day: {
                ...dayProgress,
                timer.taskId: (dayProgress[timer.taskId] ?? 0) + seconds,
              },
            }
          : null,
      newLogEntries: [
        LogEntry(now, 'timer_stopped', {
          'day': day.toString(),
          'taskId': timer.taskId,
          'seconds': seconds,
          'credited': credited,
        }),
      ],
    );
  }

  Future<void> recordExercise({int pushups = 0, int squats = 0}) async {
    await tick();
    final before = _game.state.debt;
    final next = engine.recordExercise(
      _game.state,
      today,
      pushups: pushups,
      squats: squats,
    );
    if (identical(next, _game.state)) return;
    final after = next.debt!;
    await _commit(
      _game.copyWith(
        state: next,
        newLogEntries: [
          LogEntry(_clock.now(), 'exercise', {
            'day': today.toString(),
            'pushups': after.pushupsDone - (before?.pushupsDone ?? 0),
            'squats': after.squatsDone - (before?.squatsDone ?? 0),
            'pushupsRemaining': after.pushupsRemaining,
            'squatsRemaining': after.squatsRemaining,
          }),
        ],
      ),
    );
  }

  /// Replaces the task list from tomorrow.
  Future<void> editPlan(List<TaskDefinition> tasks) async {
    await _commit(
      _game.copyWith(
        plan: _game.plan.edit(today, tasks),
        newLogEntries: [
          LogEntry(_clock.now(), 'plan_edited', {
            'effectiveFrom': today.addDays(1).toString(),
            'tasks': [for (final t in tasks) taskToJson(t)],
          }),
        ],
      ),
    );
  }

  Future<void> addBlockedApp(String package) => _changeBlockList(
    _game.blockList.add(today, package),
    'block_app_added',
    {'package': package, 'effectiveFrom': today.toString()},
  );

  Future<void> removeBlockedApp(String package) => _changeBlockList(
    _game.blockList.remove(today, package),
    'block_app_removed',
    {'package': package, 'effectiveFrom': today.addDays(1).toString()},
  );

  Future<void> _changeBlockList(
    BlockList next,
    String type,
    Map<String, Object?> data,
  ) async {
    if (identical(next, _game.blockList)) return;
    await _commit(
      _game.copyWith(
        blockList: next,
        newLogEntries: [LogEntry(_clock.now(), type, data)],
      ),
    );
  }

  /// Applies to locks scheduled after this change; a lock already scheduled
  /// keeps its time.
  Future<void> setSleepWindow(SleepWindow sleep) async {
    await _commit(
      _game.copyWith(
        sleep: sleep,
        newLogEntries: [
          LogEntry(_clock.now(), 'sleep_changed', {
            'start': sleep.startMinute,
            'end': sleep.endMinute,
          }),
        ],
      ),
    );
  }

  Future<void> allocateStat(Stat stat) async {
    final next = engine.allocateStat(_game.state, stat);
    if (identical(next, _game.state)) return;
    await _commit(
      _game.copyWith(
        state: next,
        newLogEntries: [
          LogEntry(_clock.now(), 'stat_allocated', {'stat': stat.name}),
        ],
      ),
    );
  }

  /// Logged whenever the user uses the escape from a lock.
  Future<void> recordEmergencyStop() async {
    await _commit(
      _game.copyWith(newLogEntries: [LogEntry(_clock.now(), 'emergency_stop')]),
    );
  }

  /// The emergency exit: ends the lock that is running now. Exercise owed is
  /// untouched. Returns false (and logs nothing) if no lock is running.
  Future<bool> emergencyStop() async {
    final now = _clock.now();
    final lock = _game.state.lock;
    if (lock == null || !lock.isActiveAt(now)) return false;
    await _commit(
      _game.copyWith(
        state: _game.state.copyWith(lock: () => null),
        newLogEntries: [
          LogEntry(now, 'emergency_stop', {
            'day': lock.day.toString(),
            'minutesRemaining': lock.end.difference(now).inMinutes,
          }),
        ],
      ),
    );
    return true;
  }

  /// Whether the app lock should be active right now.
  bool isLockActive() => _game.state.lock?.isActiveAt(_clock.now()) ?? false;

  String exportLogJson() =>
      const JsonEncoder.withIndent('  ')
          .convert([for (final e in _game.log) e.toJson()]);

  String exportLogCsv() {
    String cell(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final lines = ['at,type,data'];
    for (final e in _game.log) {
      lines.add(
        [
          cell(e.at.toIso8601String()),
          cell(e.type),
          cell(jsonEncode(e.data)),
        ].join(','),
      );
    }
    return lines.join('\n');
  }

  Future<void> _commit(SavedGame next) async {
    await _store.save(next);
    _game = next;
  }
}
