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
import '../domain/penalty_kind.dart';
import '../domain/progression.dart';
import '../domain/dungeon.dart';
import '../domain/system_catalogue.dart';
import '../domain/systems.dart';
import '../domain/tasks.dart';
import '../data/codec.dart';
import '../platform/usage_meter.dart';

/// The single entry point the UI uses. Every change is logged and saved.
class GameService {
  GameService._(
    this._store,
    this._clock,
    this._random,
    this.engine,
    this._game, {
    this.meter = const NoUsageMeter(),
  });

  final GameStore _store;
  final Clock _clock;
  final Random _random;
  final QuestEngine engine;

  /// Reads screen time for caps (Android usage access).
  final UsageMeter meter;

  /// Quests and Rank Trials for every System.
  final Map<SystemKind, SystemSpec> catalogue = systemCatalogue;
  SavedGame _game;

  SavedGame get game => _game;
  GameState get state => _game.state;
  DayKey get today => DayKey.fromDateTime(_clock.now());

  /// The current time on the game's clock (network-corrected on Android).
  DateTime get now => _clock.now();
  List<TaskDefinition> get todaysTasks => _tasksFor(_game, today);

  /// The user's System, or null for a game with its own written objectives.
  SystemsState? get systems => _game.systems;

  /// The quest for [day]: the System's (a Dungeon floor or the daily quest)
  /// or, in an older game, the user's own objectives.
  List<TaskDefinition> _tasksFor(SavedGame g, DayKey day) {
    final sys = g.systems;
    if (sys == null) return g.plan.tasksFor(day);
    return [for (final q in sys.questFor(catalogue, day)) questTask(q)];
  }

  DayProgress get todaysProgress => _game.progress[today] ?? const {};
  Set<String> get blockedToday => _game.blockList.packagesOn(today);

  /// Loads a saved game, or returns null if none exists yet.
  static Future<GameService?> load({
    required GameStore store,
    Clock clock = const SystemClock(),
    Random? random,
    QuestEngine? engine,
    UsageMeter meter = const NoUsageMeter(),
  }) async {
    final saved = await store.load();
    if (saved == null) return null;
    final service = GameService._(
      store,
      clock,
      random ?? Random(),
      engine ?? QuestEngine(),
      saved,
      meter: meter,
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
    UsageMeter meter = const NoUsageMeter(),
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
      meter: meter,
    );
  }

  /// Starts a new game in [system] at the [placement] rank (E to C): the
  /// System writes the quests from now on. [placementAnswers] are logged.
  static Future<GameService> awaken({
    required GameStore store,
    required SystemKind system,
    required Rank placement,
    required Set<String> blockedPackages,
    SleepWindow sleep = const SleepWindow(),
    int dryRunDays = 3,
    Map<String, Object?> placementAnswers = const {},
    Clock clock = const SystemClock(),
    Random? random,
    QuestEngine? engine,
    UsageMeter meter = const NoUsageMeter(),
  }) async {
    final now = clock.now();
    final day = DayKey.fromDateTime(now);
    final liveFrom = dryRunDays > 0 ? day.addDays(dryRunDays) : null;
    final systems = const SystemsState(progress: SystemProgress())
        .choose(system, placement, day);
    final game = SavedGame(
      state: GameState.start(day),
      plan: QuestPlan.initial(day, const []),
      progress: const {},
      blockList: BlockList.initial(day, blockedPackages),
      sleep: sleep,
      liveFrom: liveFrom,
      systems: systems,
      log: List.unmodifiable([
        LogEntry(now, 'awakened', {
          'day': day.toString(),
          'system': system.name,
          'placement': placement.name,
          'answers': placementAnswers,
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
      meter: meter,
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
    if (_game.systems != null) {
      throw StateError('A System game restarts through abandon().');
    }
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
      meter: meter,
    );
  }

  /// Archives this game and removes it, so the next launch begins a new
  /// Awakening. Refused (false) while a penalty or a Dungeon is in effect.
  Future<bool> abandon({String reason = 'trial_restarted'}) async {
    // Judge any finished day first, so a failure from just before midnight
    // can't be escaped in the seconds before the next check.
    await tick();
    if (penaltyInEffect || dungeonInProgress) return false;
    if (_game.timer != null) await stopTimer();
    await _store.archive(
      _game.copyWith(newLogEntries: [LogEntry(now, reason)]),
    );
    await _store.clear();
    return true;
  }

  /// A game from before Systems existed. It is archived (with its log) and
  /// replaced by an Awakening, unless a penalty is still in effect: then it
  /// waits until that is over.
  bool get needsMigration => _game.systems == null && !penaltyInEffect;

  /// A Dungeon floor is today or still to come.
  bool get dungeonInProgress {
    final d = _game.systems?.dungeon;
    return d != null && !d.bossDay.isBefore(today);
  }

  /// System events since the UI last asked, oldest first.
  final List<SystemEvent> _systemEvents = [];

  /// Returns and forgets System events (Gate opened, floor cleared, ...).
  List<SystemEvent> takeSystemEvents() {
    final out = [..._systemEvents];
    _systemEvents.clear();
    return out;
  }

  /// Judges any finished days. Call on app start, on resume, and at midnight.
  ///
  /// Days are judged one at a time, oldest first, so the System's verdict on
  /// one day (a Gate opening, a rank-up) shapes the quest of the next.
  Future<List<GameEvent>> tick() async {
    final now = _clock.now();
    final today = DayKey.fromDateTime(now);
    // A timer left running past midnight counts only up to midnight, and
    // must be credited before that day is judged.
    // So does one still running at a Dungeon floor's deadline.
    final timer = _game.timer;
    if (timer != null &&
        (DayKey.fromDateTime(timer.startedAt).isBefore(today) ||
            pastDeadline)) {
      await _commit(_withTimerCredited(now));
    }
    final events = <GameEvent>[];
    final log = <LogEntry>[];
    var g = _game;
    while (g.state.nextDayToClose.isBefore(today)) {
      final day = g.state.nextDayToClose;
      g = await _withCapsMeasured(g, day, final_: true);
      final sys = g.systems;
      final tasks = _tasksFor(g, day);
      final result = engine.closeDaysBefore(
        state: g.state,
        today: day.addDays(1),
        plan: g.plan,
        tasksFor: (_) => tasks,
        progressFor: (d) => g.progress[d] ?? const {},
        sleep: g.sleep,
        random: _random,
        now: now,
        isEnforced: g.isEnforced,
        // A failed Dungeon floor: double lock, double reps.
        penaltyMultiplier: (d) => sys != null && sys.isDungeonDay(d)
            ? DungeonRules.failMultiplier
            : 1,
        xpPercent: (d) => tasks.isEmpty
            ? 0 // no quest (no System chosen yet): nothing to earn
            : sys != null &&
                  !sys.isDungeonDay(d) &&
                  sys.progress.reductionOn(d) > 0
            ? 50 // the reduction valve halves the day's XP
            : 100,
        // Each System's own penalty; older games stay on exercise.
        penaltyKind: (_) => penaltyKindFor(sys?.active),
      );
      var state = result.state;
      events.addAll(result.events);
      log.addAll([for (final e in result.events) LogEntry.fromEvent(now, e)]);
      var nextSys = sys;
      if (sys != null) {
        final cleared = result.events.any((e) => e is QuestCleared);
        final (after, sysEvents) = sys.afterDayClosed(
          day: day,
          cleared: cleared,
          dryRun: !g.isEnforced(day),
          now: now,
        );
        nextSys = after;
        for (final e in sysEvents) {
          if (e is DungeonCleared) {
            state = state.copyWith(
              unspentStatPoints:
                  state.unspentStatPoints + DungeonRules.clearStatPoints,
            );
          }
          _systemEvents.add(e);
          log.add(LogEntry.fromSystemEvent(now, e));
        }
      }
      g = SavedGame(
        state: state,
        plan: g.plan,
        progress: g.progress,
        blockList: g.blockList,
        sleep: g.sleep,
        log: g.log,
        timer: g.timer,
        liveFrom: g.liveFrom,
        systems: nextSys,
      );
    }
    // A Dungeon whose floors all lie in already-judged days (only possible
    // after clock changes) is closed, so it can't block Gates for good.
    final stale = g.systems?.dungeon;
    if (stale != null && stale.bossDay.isBefore(g.state.nextDayToClose)) {
      g = g.copyWith(systems: g.systems!.copyWith(dungeon: () => null));
    }
    final sys = g.systems;
    if (sys != null) {
      final (after, expired) = sys.expireGate(now);
      if (expired.isNotEmpty) {
        g = g.copyWith(systems: after);
        _systemEvents.addAll(expired);
        log.addAll([for (final e in expired) LogEntry.fromSystemEvent(now, e)]);
      }
    }
    // Issue today's quest: it is fixed from now until today is judged.
    final current = g.systems;
    if (current != null) {
      final issued = current.issue(catalogue, today);
      if (!identical(issued, current)) g = g.copyWith(systems: issued);
    }
    if (log.isEmpty && identical(g, _game)) return const [];
    await _commit(g.copyWith(newLogEntries: log));
    return events;
  }

  /// Measures screen-time caps on [day] from the phone's usage data: up to
  /// now, or the whole day when [final_]. Without usage access nothing is
  /// changed, so an honour confirmation (see [confirmCap]) stands.
  Future<SavedGame> _withCapsMeasured(
    SavedGame g,
    DayKey day, {
    bool final_ = false,
  }) async {
    final caps = [
      for (final t in _tasksFor(g, day))
        if (t.isCap) t,
    ];
    if (caps.isEmpty) return g;
    final now = _clock.now();
    // A floor with a deadline is measured only up to its deadline.
    var end = day.addDays(1).at(0);
    final deadline = g.systems?.deadlineOn(day);
    if (deadline != null && deadline.isBefore(end)) end = deadline;
    final to = final_ || now.isAfter(end) ? end : now;
    final minutes = await meter.minutesUsed(
      g.blockList.packagesOn(day),
      day.at(0),
      to,
    );
    if (minutes == null) {
      if (!final_) return g;
      // No reading at judging: a partial reading from earlier in the day
      // must not stand. Only an honour confirmation does.
      final kept = {...?g.progress[day]};
      var changed = false;
      for (final t in caps) {
        if (!kept.containsKey(t.id) || _honoured(g, day, t.id)) continue;
        kept.remove(t.id);
        changed = true;
      }
      if (!changed) return g;
      return g.copyWith(
        progress: {...g.progress, day: kept},
        newLogEntries: [
          LogEntry(now, 'cap_unmeasured', {'day': day.toString()}),
        ],
      );
    }
    final dayProgress = {
      ...?g.progress[day],
      for (final t in caps) t.id: minutes,
    };
    return g.copyWith(
      progress: {...g.progress, day: dayProgress},
      newLogEntries: final_
          ? [
              LogEntry(now, 'cap_measured', {
                'day': day.toString(),
                'minutes': minutes,
              }),
            ]
          : const [],
    );
  }

  /// Whether the user confirmed [taskId] on [day] on the honour system.
  static bool _honoured(SavedGame g, DayKey day, String taskId) => g.log.any(
    (e) =>
        e.type == 'progress' &&
        e.data['day'] == day.toString() &&
        e.data['taskId'] == taskId &&
        e.data['honour'] == true,
  );

  /// Re-reads today's screen time for any cap in today's quest.
  Future<void> measureCaps() async {
    final next = await _withCapsMeasured(_game, today);
    if (!identical(next, _game)) await _commit(next);
  }

  /// Whether today's screen time can be measured automatically.
  Future<bool> canMeasureCaps() async =>
      await meter.minutesUsed(const {}, today.at(0), now) != null;

  /// Honour-system confirmation that a cap was kept, for phones without
  /// usage access. Ignored when the phone can measure it.
  Future<bool> confirmCap(String taskId) async {
    final task = todaysTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || !task.isCap) return false;
    if (await canMeasureCaps()) return false;
    // A reading already over the cap today can't be confirmed away.
    final read = todaysProgress[taskId];
    if (read != null && read > task.target) return false;
    await _setProgress(task, task.target, honour: true);
    return true;
  }

  /// Enters the open Gate: Floor 1 is tomorrow. Returns false when no Gate
  /// is open (or it has just expired).
  Future<bool> enterGate() async {
    await tick();
    final sys = _game.systems;
    final entered = sys?.enter(now, firstOpenDay: _game.state.nextDayToClose);
    if (entered == null) return false;
    final (next, event) = entered;
    _systemEvents.add(event);
    await _commit(
      _game.copyWith(
        systems: next,
        newLogEntries: [LogEntry.fromSystemEvent(now, event)],
      ),
    );
    return true;
  }

  /// Sets the reduction valve (0-20%) from tomorrow. While it is above zero
  /// each cleared day earns half XP. Logged every time.
  Future<void> setReduction(int percent) async {
    final sys = _game.systems;
    if (sys == null || sys.active == null) return;
    final value = percent.clamp(0, maxQuestReduction);
    if (sys.progress.reductionOn(today.addDays(1)) == value) return;
    await _commit(
      _game.copyWith(
        systems: sys.copyWith(
          progress: sys.progress.setReduction(today, value),
        ),
        newLogEntries: [
          LogEntry(now, 'reduction_set', {
            'percent': value,
            'effectiveFrom': today.addDays(1).toString(),
          }),
        ],
      ),
    );
  }

  /// The reduction in force today, and the one set for tomorrow.
  int get reductionToday => _game.systems?.progress.reductionOn(today) ?? 0;
  int get reductionTomorrow =>
      _game.systems?.progress.reductionOn(today.addDays(1)) ?? 0;

  /// Chooses the next System once the current one is complete. Its quests
  /// start today. Returns false when choosing isn't allowed.
  Future<bool> chooseSystem(
    SystemKind kind,
    Rank placement, {
    Map<String, Object?> answers = const {},
  }) async {
    final sys = _game.systems;
    if (sys == null || !sys.progress.canChooseSystem) return false;
    if (sys.progress.completed.contains(kind)) return false;
    if (placement.index > highestPlacement.index) return false;
    // The new quest starts tomorrow, so it is never judged on a day the
    // user had no chance to do it.
    final next = sys.choose(kind, placement, today.addDays(1));
    await _commit(
      _game.copyWith(
        systems: next,
        newLogEntries: [
          LogEntry(now, 'system_chosen', {
            'day': today.toString(),
            'system': kind.name,
            'placement': placement.name,
            'answers': answers,
            'startsOn': today.addDays(1).toString(),
          }),
        ],
      ),
    );
    return true;
  }

  /// Every 30 days of the trial (from day 31, 61, ...) a report is issued
  /// once, even if the app wasn't opened on that exact day.
  bool get reportDue {
    final owed = (trialDay - 1) ~/ 30;
    final issued = _game.log.where((e) => e.type == 'report_issued').length;
    return issued < owed;
  }

  Future<void> markReportIssued() => _commit(
    _game.copyWith(
      newLogEntries: [
        LogEntry(now, 'report_issued', {'day': today.toString()}),
      ],
    ),
  );

  /// A Dungeon Penalty applies today (the day after a failed floor).
  bool get dungeonPenaltyToday =>
      _game.systems?.dungeonPenaltyDay == today && penaltyInEffect;

  /// Floor 2's 18:00 deadline today, if today is Floor 2.
  DateTime? get deadlineToday => _game.systems?.deadlineOn(today);

  /// Today's deadline has passed: progress can no longer be recorded.
  bool get pastDeadline {
    final d = deadlineToday;
    return d != null && !now.isBefore(d);
  }

  /// Sets today's progress on [taskId]. Ignored for unknown tasks, for caps
  /// (they are measured, or confirmed with [confirmCap]) and after a
  /// Dungeon floor's deadline.
  Future<void> setProgress(String taskId, int value) async {
    await tick();
    final task = todaysTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.isCap) return;
    await _setProgress(task, value);
  }

  Future<void> _setProgress(
    TaskDefinition task,
    int value, {
    bool honour = false,
  }) async {
    final taskId = task.id;
    final day = today;
    if (!_game.state.isOpen(day) || pastDeadline) return;
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
            if (honour) 'honour': true,
          }),
        ],
      ),
    );
  }

  Future<void> addProgress(String taskId, int delta) =>
      setProgress(taskId, (todaysProgress[taskId] ?? 0) + delta);

  bool isTimerRunning(String taskId) => _game.timer?.taskId == taskId;

  /// Today's progress, including time on a timer that is still running
  /// (seconds for timer tasks). Null when nothing is recorded for a cap:
  /// an unmeasured cap is not kept.
  int? liveProgress(String taskId) {
    final recorded = todaysProgress[taskId];
    final saved = recorded ?? 0;
    final timer = _game.timer;
    if (timer == null || timer.taskId != taskId) {
      return recorded ?? _zero(taskId);
    }
    if (DayKey.fromDateTime(timer.startedAt) != today) return saved;
    final running = _timerEnd(
      timer,
      _clock.now(),
    ).difference(timer.startedAt).inSeconds;
    // A phone-free block counts the longest single block, not the total.
    return _isPhoneFree(taskId)
        ? max(saved, max(0, running))
        : saved + max(0, running);
  }

  int? _zero(String taskId) {
    final t = todaysTasks.where((t) => t.id == taskId).firstOrNull;
    return t != null && t.isCap ? null : 0;
  }

  bool _isPhoneFree(String taskId) =>
      todaysTasks.any((t) => t.id == taskId && t.type == TaskType.phoneFree);

  /// Where a timer stops counting: now, but never past its day's midnight
  /// or a Dungeon floor's deadline.
  DateTime _timerEnd(RunningTimer timer, DateTime now) {
    final day = DayKey.fromDateTime(timer.startedAt);
    var end = day.addDays(1).at(0);
    final deadline = _game.systems?.deadlineOn(day);
    if (deadline != null && deadline.isBefore(end)) end = deadline;
    return now.isAfter(end) ? end : now;
  }

  /// The phone-free block running now, if any: the chosen apps stay locked
  /// until it is paused.
  RunningTimer? get focusBlock {
    final timer = _game.timer;
    if (timer == null) return null;
    if (timer.taskId != penaltyBlockId && !_isPhoneFree(timer.taskId)) {
      return null;
    }
    return timer;
  }

  /// Seconds elapsed on the running timer for [taskId], for a live display.
  int runningSeconds(String taskId) {
    final timer = _game.timer;
    if (timer == null || timer.taskId != taskId) return 0;
    return max(
      0,
      _timerEnd(timer, _clock.now()).difference(timer.startedAt).inSeconds,
    );
  }

  Future<void> startTimer(String taskId) async {
    await tick();
    final task = todaysTasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return;
    if (task.type != TaskType.timer && task.type != TaskType.phoneFree) return;
    if (!_game.state.isOpen(today) || pastDeadline) return;
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
  /// counting no further than that day's midnight (or a floor's deadline).
  /// A phone-free block keeps the longest single block instead of a total.
  SavedGame _withTimerCredited(DateTime now) {
    final timer = _game.timer!;
    if (timer.taskId == penaltyBlockId) return _withPenaltyBlockCredited(now);
    final day = DayKey.fromDateTime(timer.startedAt);
    final end = _timerEnd(timer, now);
    final seconds = max(0, end.difference(timer.startedAt).inSeconds);
    final credited = _game.state.isOpen(day);
    final dayProgress = _game.progress[day] ?? const {};
    final before = dayProgress[timer.taskId] ?? 0;
    final phoneFree = _tasksFor(
      _game,
      day,
    ).any((t) => t.id == timer.taskId && t.type == TaskType.phoneFree);
    return _game.copyWith(
      timer: () => null,
      progress: credited
          ? {
              ..._game.progress,
              day: {
                ...dayProgress,
                timer.taskId: phoneFree
                    ? max(before, seconds)
                    : before + seconds,
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

  /// Records penalty work done today: push-ups and squats, pages and
  /// reflections. Focus minutes are earned only with [startPenaltyBlock].
  Future<void> recordPenalty({int primary = 0, int secondary = 0}) async {
    await tick();
    final kind = _game.state.debt?.kind;
    // Focus minutes come only from a penalty block; reflections only from
    // submitReflection.
    if (kind == PenaltyKind.focus && primary != 0) return;
    if (kind == PenaltyKind.reading && secondary != 0) return;
    final before = _game.state.debt;
    final next = engine.recordPenalty(
      _game.state,
      today,
      primary: primary,
      secondary: secondary,
    );
    if (identical(next, _game.state)) return;
    final after = next.debt!;
    await _commit(
      _game.copyWith(
        state: next,
        newLogEntries: [
          LogEntry(_clock.now(), 'penalty_work', {
            'day': today.toString(),
            'kind': after.kind.name,
            'primary': after.primaryDone - (before?.primaryDone ?? 0),
            'secondary': after.secondaryDone - (before?.secondaryDone ?? 0),
            'primaryRemaining': after.primaryRemaining,
            'secondaryRemaining': after.secondaryRemaining,
          }),
        ],
      ),
    );
  }

  /// Pays one reflection of a reading penalty with the user's [text], which
  /// is kept in the trial log. Refused unless it is long enough.
  Future<bool> submitReflection(String text) async {
    await tick();
    final debt = _game.state.debt;
    if (debt == null ||
        debt.kind != PenaltyKind.reading ||
        debt.dueDay != today ||
        debt.secondaryRemaining == 0 ||
        !reflectionAccepted(text)) {
      return false;
    }
    await _commit(
      _game.copyWith(
        state: _game.state.copyWith(debt: () => debt.record(secondary: 1)),
        newLogEntries: [
          LogEntry(now, 'reflection', {
            'day': today.toString(),
            'text': text.trim(),
          }),
        ],
      ),
    );
    return true;
  }

  /// The timer id used for a Focus penalty block.
  static const penaltyBlockId = '__penalty_block__';

  /// Whether a Focus penalty block is running.
  bool get penaltyBlockRunning => _game.timer?.taskId == penaltyBlockId;

  /// Seconds into the running penalty block.
  int get penaltyBlockSeconds {
    final timer = _game.timer;
    if (timer == null || timer.taskId != penaltyBlockId) return 0;
    return max(0, _clock.now().difference(timer.startedAt).inSeconds);
  }

  /// Starts paying a Focus penalty: a phone-free block that locks the
  /// chosen apps until it is ended. Any running quest timer is stopped first.
  Future<void> startPenaltyBlock() async {
    await tick();
    final debt = _game.state.debt;
    if (debt == null ||
        debt.kind != PenaltyKind.focus ||
        debt.dueDay != today ||
        debt.isPaid ||
        penaltyBlockRunning) {
      return;
    }
    var next = _game.timer == null ? _game : _withTimerCredited(now);
    next = next.copyWith(
      timer: () => RunningTimer(penaltyBlockId, now),
      newLogEntries: [
        LogEntry(now, 'penalty_block_started', {'day': today.toString()}),
      ],
    );
    await _commit(next);
  }

  /// Ends the penalty block and credits its whole minutes to the debt of
  /// the day it started (never past that day's midnight).
  SavedGame _withPenaltyBlockCredited(DateTime now) {
    final timer = _game.timer!;
    final day = DayKey.fromDateTime(timer.startedAt);
    final midnight = day.addDays(1).at(0);
    final end = now.isAfter(midnight) ? midnight : now;
    final minutes = max(0, end.difference(timer.startedAt).inMinutes);
    final debt = _game.state.debt;
    final credited = debt != null && debt.dueDay == day && minutes > 0;
    return _game.copyWith(
      timer: () => null,
      state: credited
          ? _game.state.copyWith(debt: () => debt.record(primary: minutes))
          : null,
      newLogEntries: [
        LogEntry(now, 'penalty_block_ended', {
          'day': day.toString(),
          'minutes': minutes,
          'credited': credited,
        }),
      ],
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

  /// Logs that the blocker service was found switched off (for example by a
  /// force stop), and whether auto-repair turned it back on. These entries
  /// can't be removed, so the day-30 review sees every one.
  Future<void> recordBlockerOffline({required bool repaired}) async {
    await _commit(
      _game.copyWith(
        newLogEntries: [
          LogEntry(_clock.now(), 'blocker_offline', {
            'day': today.toString(),
            'duringPenalty': penaltyInEffect,
            'repaired': repaired,
          }),
        ],
      ),
    );
  }

  /// Times the blocker was found switched off during this trial.
  int get blockerOfflineIncidents =>
      _game.log.where((e) => e.type == 'blocker_offline').length;

  /// How long one release lasts.
  static const releaseLength = Duration(minutes: 15);

  /// A short release from the running lock. It can be taken again and again,
  /// but every one is counted and shown, and none moves the lock's end.
  /// Exercise owed is untouched. Returns false (and logs nothing) unless the
  /// lock is actually in force right now.
  Future<bool> releaseLock() async {
    final now = _clock.now();
    final lock = _game.state.lock;
    if (lock == null || !lock.isActiveAt(now)) return false;
    final released = lock.releaseAt(now, releaseLength);
    await _commit(
      _game.copyWith(
        state: _game.state.copyWith(lock: () => released),
        newLogEntries: [
          LogEntry(now, 'lock_released', {
            'day': lock.day.toString(),
            'release': released.releases,
            'until': released.releasedUntil!.toIso8601String(),
            'lockMinutesRemaining': lock.end.difference(now).inMinutes,
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
