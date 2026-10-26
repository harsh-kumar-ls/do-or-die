import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/game_service.dart';
import '../app/notification_planner.dart';
import '../app/penalty_enforcer.dart';
import '../app/trusted_clock.dart';
import '../platform/blocker.dart';
import '../platform/notifier.dart';
import '../domain/day.dart';
import '../domain/dungeon.dart';
import '../domain/engine.dart';
import '../domain/progression.dart';
import '../domain/system_catalogue.dart';
import '../domain/systems.dart';
import '../domain/tasks.dart';
import 'fx.dart';

/// A System notice waiting to be shown.
class SystemNotice {
  const SystemNotice({
    required this.title,
    required this.lines,
    this.levelUp,
    this.danger = false,
    this.cue,
  });

  final String title;
  final List<String> lines;
  final int? levelUp;
  final bool danger;

  /// Overrides the default sound for this notice.
  final Cue? cue;
}

/// Wraps [GameService] for the UI: rebuilds listeners after every change,
/// re-judges days on resume and every 30 seconds, and queues notices.
class GameModel extends ChangeNotifier with WidgetsBindingObserver {
  /// [pollEvery] null disables the periodic re-check (used in tests).
  /// [enforcer] pushes penalties to the phone's blocker; null in tests that
  /// don't need it.
  GameModel(
    this.service, {
    this.enforcer,
    this.notifier,
    this.trustedClock,
    this.planner = const NotificationPlanner(),
    Duration? pollEvery = const Duration(seconds: 30),
  }) {
    WidgetsBinding.instance.addObserver(this);
    if (pollEvery != null) {
      _poll = Timer.periodic(pollEvery, (_) => tick());
    }
    _wasComplete = isQuestComplete;
    unawaited(tick());
  }

  final GameService service;
  final PenaltyEnforcer? enforcer;

  /// Schedules OS notifications; null in tests that don't need it.
  final Notifier? notifier;

  /// Corrects the phone's clock with network time; null in tests.
  final TrustedClock? trustedClock;
  final NotificationPlanner planner;

  bool _notificationsAllowed = true;
  bool _exactTiming = true;

  /// Latest System Check reading; null until first read (or on web).
  SystemStatus? system;

  /// Whether the blocker was on at the last check; null before the first.
  bool? _blockerWasOn;

  /// Checks the blocker service is still on. If it was switched off (a force
  /// stop does this), tries auto-repair, and logs one incident per outage.
  Future<void> _watchBlocker() async {
    final blocker = enforcer?.blocker;
    if (blocker == null || !blocker.canBlock) return;
    try {
      var status = await blocker.systemStatus();
      if (!status.serviceEnabled) {
        // A force stop kills the watcher; restarting it needs no special
        // permission, only the two the user already granted.
        final repaired = await blocker.startWatcher();
        if (_blockerWasOn != false) {
          await service.recordBlockerOffline(repaired: repaired);
        }
        if (repaired) status = await blocker.systemStatus();
      }
      _blockerWasOn = status.serviceEnabled;
      system = status;
    } catch (e) {
      debugPrint('System check failed: $e');
    }
  }

  /// Requirements not met (0 on web or before the first check).
  int get systemIssues {
    final s = system;
    if (s == null) return 0;
    return [
      !s.serviceEnabled,
      !s.batteryExempt,
      !s.autoTime,
      notificationsBlocked,
      lateNotices,
    ].where((bad) => bad).length;
  }

  /// The blocker service was found switched off.
  bool get blockerOffline => system?.serviceEnabled == false;

  /// Re-reads the System Check now (used by the System Check screen).
  Future<void> refreshSystem() async {
    await _sync();
    notifyListeners();
  }

  /// The current time on the game's (trusted) clock.
  DateTime get now => service.now;

  /// Automatic date and time is off, so the phone's clock can't be trusted.
  bool get manualClock => trustedClock != null && !trustedClock!.autoTime;

  /// The user has blocked Do or Die's notifications.
  bool get notificationsBlocked => notifier != null && !_notificationsAllowed;

  /// Notices may arrive up to an hour late until "Alarms & reminders" is on.
  bool get lateNotices =>
      notifier != null && _notificationsAllowed && !_exactTiming;

  Future<void> requestExactTiming() async => notifier?.requestExact();

  Future<void> openDateSettings() async =>
      trustedClock?.source.openDateSettings();

  Future<void> requestNotifications() async {
    _notificationsAllowed = await notifier?.requestPermission() ?? true;
    await _sync();
    notifyListeners();
  }

  Timer? _poll;
  final List<SystemNotice> _notices = [];
  late bool _wasComplete;

  SystemNotice? get notice => _notices.firstOrNull;

  void dismissNotice() {
    if (_notices.isEmpty) return;
    _notices.removeAt(0);
    notifyListeners();
  }

  GameState get state => service.state;
  List<TaskDefinition> get tasks => service.todaysTasks;

  /// Progress for display; 0 when nothing is recorded yet.
  int progress(TaskDefinition t) => service.liveProgress(t.id) ?? 0;

  /// Whether a cap has a reading (measured or confirmed) today.
  bool isMeasured(TaskDefinition t) => service.liveProgress(t.id) != null;
  bool isDone(TaskDefinition t) => t.isComplete(service.liveProgress(t.id));
  bool get isQuestComplete => tasks.isNotEmpty && tasks.every(isDone);

  /// The System rank, or (in an older game) the rank for the level.
  Rank get rank =>
      service.systems?.rank ??
      service.engine.progression.rankForLevel(state.level);

  // ---- Systems & Dungeons ----------------------------------------------

  SystemsState? get systems => service.systems;
  SystemSpec? get systemSpec =>
      systems?.active == null ? null : systemCatalogue[systems!.active!];

  /// The Dungeon floor today (1-3), or 0.
  int get floorToday => systems?.floorOn(service.today) ?? 0;

  /// An open Gate waiting to be entered.
  Gate? get gate => systems?.gate;

  /// Cleared days in the 30-day window, up to yesterday.
  int get clearedInWindow =>
      systems?.clearedInWindow(service.today.addDays(-1)) ?? 0;

  /// The day after a failed floor: the Dungeon Penalty look and rules.
  bool get dungeonPenalty => service.dungeonPenaltyToday;

  /// Floor 2's deadline today, if any.
  DateTime? get deadlineToday => service.deadlineToday;

  /// The current System is complete and a new one may be chosen.
  bool get canChooseSystem =>
      systems != null && systems!.progress.canChooseSystem;

  /// Days before a Gate may open again, or 0.
  int get gateBlockedDays {
    final until = systems?.gateBlockedUntil;
    if (until == null) return 0;
    return daysLeft(service.today, until);
  }

  int get reductionToday => service.reductionToday;
  int get reductionTomorrow => service.reductionTomorrow;

  Future<void> setReduction(int percent) =>
      _run(() => service.setReduction(percent));

  Future<bool> enterGate() async {
    var ok = false;
    await _run(() async => ok = await service.enterGate());
    _drainSystemEvents();
    notifyListeners();
    return ok;
  }

  Future<bool> chooseSystem(
    SystemKind kind,
    Rank placement,
    Map<String, int> answers,
  ) async {
    var ok = false;
    await _run(
      () async =>
          ok = await service.chooseSystem(kind, placement, answers: answers),
    );
    return ok;
  }

  int get xpToNext => service.engine.progression.xpToNextLevel(state.level);

  /// XP for clearing today: half while the reduction valve is in force.
  int get xpReward => service.reductionToday > 0
      ? service.engine.config.xpPerClear ~/ 2
      : service.engine.config.xpPerClear;

  bool get hasDebt =>
      !(state.debt?.isPaid ?? true) && state.debt!.dueDay == service.today;
  bool get lockActive => service.isLockActive();

  /// A lock is scheduled for today but hasn't started. Its start time is
  /// deliberately not shown.
  bool get lockPending {
    final lock = state.lock;
    if (lock == null || lock.day != service.today) return false;
    return now.isBefore(lock.start);
  }

  bool get inPenalty => hasDebt || lockActive || lockPending || lockReleased;

  /// Whether screen-time caps are read automatically (usage access).
  bool capsMeasurable = false;

  /// Floor 2's deadline has passed today.
  bool get pastDeadline => service.pastDeadline;

  Future<void> confirmCap(TaskDefinition t) =>
      _run(() => service.confirmCap(t.id));

  Future<void> tick() async {
    await _refreshClock();
    final events = await service.tick();
    if (tasks.any((t) => t.isCap)) {
      capsMeasurable = await service.canMeasureCaps();
      await service.measureCaps();
    }
    await _sync();
    if (service.reportDue) {
      await service.markReportIssued();
      _queue(
        SystemNotice(
          title: '[ REPORT ]',
          lines: [
            '${service.trialDay - 1} days have passed.',
            'The report is ready. Open it from the Status tab.',
          ],
        ),
      );
      notifyListeners();
    }
    final systemEvents = service.takeSystemEvents();
    if (events.isEmpty && systemEvents.isEmpty) {
      notifyListeners(); // clock or permission state may have changed
      return;
    }
    _noticesFor(events, systemEvents);
    _wasComplete = isQuestComplete;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() op) async {
    await op();
    await _sync();
    _checkCompletion();
    notifyListeners();
  }

  Future<void> _refreshClock() async {
    try {
      await trustedClock?.refresh();
    } catch (e) {
      debugPrint('Could not read trusted time: $e');
    }
  }

  /// Keeps the phone's blocker and scheduled notifications in step with the
  /// game. A failure here must never break the app, so it is logged and
  /// retried on the next change.
  Future<void> _sync() async {
    try {
      await enforcer?.sync(service);
    } catch (e) {
      debugPrint('Could not sync the blocker: $e');
    }
    await _watchBlocker();
    final n = notifier;
    if (n == null) return;
    try {
      _notificationsAllowed = await n.isPermitted();
      _exactTiming = await n.canBeExact();
      // Plans are on the trusted clock; the OS fires by the phone's clock.
      final shift = trustedClock?.deviceOffset ?? Duration.zero;
      await n.apply([
        for (final p in planner.plan(service, now))
          PlannedNotice(p.id, p.at.subtract(shift), p.title, p.body),
      ]);
    } catch (e) {
      debugPrint('Could not schedule notifications: $e');
    }
  }

  Future<void> addBlockedApp(String package) =>
      _run(() => service.addBlockedApp(package));

  Future<void> removeBlockedApp(String package) =>
      _run(() => service.removeBlockedApp(package));

  /// Apps that will no longer be locked from tomorrow.
  Set<String> get pendingUnblocks {
    final tomorrow = service.today.addDays(1);
    return service.blockedToday.difference(
      service.game.blockList.packagesOn(tomorrow),
    );
  }

  /// Takes a 15-minute release from the running lock. Returns false if the
  /// lock isn't in force right now.
  Future<bool> releaseLock() async {
    var released = false;
    await _run(() async => released = await service.releaseLock());
    return released;
  }

  /// Inside today's lock window, but in a short release.
  bool get lockReleased => state.lock?.isReleasedAt(now) ?? false;

  /// When the current release ends, if one is running.
  DateTime? get releaseEndsAt =>
      lockReleased ? state.lock!.releasedUntil : null;

  /// Why RESTART TRIAL is unavailable right now, or null if it's available.
  /// Never reveals when a scheduled lock will start.
  String? get restartBlockedReason {
    if (service.dungeonInProgress && !service.penaltyInEffect) {
      return 'Restart unlocks after the Dungeon ends.';
    }
    if (!service.penaltyInEffect) return null;
    final parts = <String>[];
    final debt = state.debt;
    if (debt != null && debt.dueDay == service.today && !debt.isPaid) {
      parts.add(
        [
          if (debt.pushupsRemaining > 0) '${debt.pushupsRemaining} push-ups',
          if (debt.squatsRemaining > 0) '${debt.squatsRemaining} squats',
        ].join(' and '),
      );
    }
    final lock = state.lock;
    final lockLeft = lock != null && lock.end.isAfter(now);
    final owes = parts.isNotEmpty;
    if (owes && lockLeft) {
      return "Finish today's ${parts.single} and wait for today's lock to end to unlock restart.";
    }
    if (owes) return "Finish today's ${parts.single} to unlock restart.";
    if (lockLeft && lock.inWindowAt(now)) {
      return "Restart unlocks when today's lock ends at ${_hm(lock.end)}.";
    }
    return "Restart unlocks after today's lock ends.";
  }

  /// Releases taken during today's lock.
  int get releasesUsed {
    final lock = state.lock;
    return lock != null && lock.day == service.today ? lock.releases : 0;
  }

  Future<void> addProgress(TaskDefinition t, int delta) =>
      _run(() => service.addProgress(t.id, delta));

  Future<void> setProgress(TaskDefinition t, int value) =>
      _run(() => service.setProgress(t.id, value));

  Future<void> toggleTimer(TaskDefinition t) {
    final running = service.isTimerRunning(t.id);
    Fx.instance.play(running ? Cue.timerStop : Cue.timerStart);
    return _run(() => running ? service.stopTimer() : service.startTimer(t.id));
  }

  bool isTimerRunning(TaskDefinition t) => service.isTimerRunning(t.id);
  int runningSeconds(TaskDefinition t) => service.runningSeconds(t.id);

  Future<void> recordExercise({int pushups = 0, int squats = 0}) {
    Fx.instance.play(Cue.rep);
    return _run(() => service.recordExercise(pushups: pushups, squats: squats));
  }

  Future<void> allocateStat(Stat stat) {
    if (state.unspentStatPoints > 0) Fx.instance.play(Cue.confirm);
    return _run(() => service.allocateStat(stat));
  }

  /// Queues a notice and plays its cue as it appears.
  void _queue(SystemNotice n) {
    _notices.add(n);
    Fx.instance.play(
      n.cue ??
          (n.levelUp != null
              ? Cue.levelUp
              : n.danger
              ? Cue.penalty
              : Cue.notice),
    );
  }

  /// Running timers can complete a task without any tap, so check on every
  /// rebuild tick too.
  void checkCompletion() {
    if (_checkCompletion()) notifyListeners();
  }

  bool _checkCompletion() {
    final complete = isQuestComplete;
    final changed = complete && !_wasComplete;
    _wasComplete = complete;
    if (changed) {
      _queue(
        SystemNotice(
          title: '[ NOTIFICATION ]',
          lines: [
            'The daily quest has been completed.',
            'Reward: +$xpReward XP',
            'The reward is granted when the day ends.',
          ],
        ),
      );
    }
    return changed;
  }

  void _drainSystemEvents() => _systemNotices(service.takeSystemEvents());

  void _noticesFor(List<GameEvent> events, List<SystemEvent> systemEvents) {
    // A failed floor gets the Dungeon notice instead of the ordinary one.
    final failedFloors = {
      for (final e in systemEvents.whereType<DungeonFailed>()) e.day,
    };
    for (final e in events) {
      if (e is QuestFailed && failedFloors.contains(e.day)) continue;
      switch (e) {
        case QuestCleared(:final xpGained):
          final levels = events.whereType<LevelUp>().where(
            (l) => l.day == e.day,
          );
          _queue(
            SystemNotice(
              title: '[ NOTIFICATION ]',
              lines: [
                'Quest for ${_dayName(e)} cleared.',
                'Reward granted: +$xpGained XP',
              ],
              levelUp: levels.isEmpty ? null : levels.last.newLevel,
            ),
          );
        case QuestFailed():
          final penalty = events
              .whereType<PenaltyIssued>()
              .where((p) => p.day == e.day)
              .firstOrNull;
          final lock = events
              .whereType<LockScheduled>()
              .where((l) => l.day == e.day.addDays(1))
              .firstOrNull;
          final exercise = penalty == null
              ? null
              : '${penalty.pushups} push-ups${penalty.squats > 0 ? ', ${penalty.squats} squats' : ''}';
          if (penalty != null && !penalty.enforced) {
            // Dry run: nothing is enforced, so the whole penalty is shown.
            final live = service.liveFrom;
            _queue(
              SystemNotice(
                title: '[ DRY RUN ]',
                lines: [
                  'Quest for ${_dayName(e)} was not completed.',
                  'Penalty that would apply: $exercise.',
                  if (lock != null)
                    'Lock that would apply: ${_hm(lock.window.start)} to ${_hm(lock.window.end)}.',
                  if (live != null)
                    'Not enforced. Penalties go live on ${_dateName(live)}.',
                ],
              ),
            );
          } else {
            _queue(
              SystemNotice(
                title: '[ WARNING ]',
                danger: true,
                lines: [
                  'Quest for ${_dayName(e)} was not completed.',
                  if (exercise != null) 'Penalty issued: $exercise.',
                  if (lock != null)
                    'A lock will begin at an undisclosed time today.',
                ],
              ),
            );
          }
        default:
          break;
      }
    }
    _systemNotices(systemEvents);
  }

  static String _r(Rank r) => r.name.toUpperCase();

  void _systemNotices(List<SystemEvent> events) {
    for (final e in events) {
      _queue(switch (e) {
        GateOpened(:final gate) => SystemNotice(
          title: '[ GATE ]',
          cue: Cue.gateOpen,
          lines: [
            'A Gate has opened.',
            'Rank ${_r(gate.from)} Dungeon. Enter within 48 hours.',
            'Clear three floors to reach rank ${_r(Rank.values[gate.from.index + 1])}.',
          ],
        ),
        GateExpired() => const SystemNotice(
          title: '[ NOTIFICATION ]',
          lines: ['The Gate has closed.', 'It may open again in 3 days.'],
        ),
        DungeonEntered() => const SystemNotice(
          title: '[ DUNGEON ]',
          cue: Cue.gateOpen,
          lines: [
            'You have entered the Dungeon.',
            'Floor 1 begins at 00:00.',
            'Floor 2 must be cleared by 18:00.',
            'Floor 3 is the Rank Trial.',
          ],
        ),
        FloorCleared(:final floor) => SystemNotice(
          title: '[ DUNGEON ]',
          lines: [
            'Floor $floor cleared.',
            floor == 1
                ? 'Floor 2 begins. Clear it by 18:00.'
                : 'The Rank Trial begins.',
          ],
        ),
        DungeonCleared(:final newRank, :final title) => SystemNotice(
          title: '[ RANK UP ]',
          cue: Cue.rankUp,
          lines: [
            'The Dungeon has been cleared.',
            'Rank ${_r(newRank)}.',
            'Title earned: $title.',
            '+${DungeonRules.clearStatPoints} stat points.',
          ],
        ),
        DungeonFailed(:final floor) => SystemNotice(
          title: '[ DUNGEON FAILED ]',
          danger: true,
          cue: Cue.dungeonPenalty,
          lines: [
            'Floor $floor was not cleared.',
            service.isDryRunToday
                ? 'Dry run: no penalty is enforced.'
                : 'Dungeon Penalty today: double lock and double reps.',
            'The Gate is shut for ${DungeonRules.failCooldown} days. Your rank is kept.',
          ],
        ),
        SystemCompleted(:final system) => SystemNotice(
          title: '[ SYSTEM COMPLETE ]',
          cue: Cue.rankUp,
          lines: [
            '${systemCatalogue[system]!.name} complete.',
            'Rank S held for ${SystemsState.catalogueHoldDays} days.',
            'A new System may now be chosen.',
          ],
        ),
      });
    }
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _dateName(DayKey d) {
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return '${names[DateTime(d.year, d.month, d.day).weekday - 1]} ${d.day}';
  }

  /// "DRY RUN" or "LIVE", with the go-live date while in dry run.
  String get trialMode {
    final live = service.liveFrom;
    return service.isDryRunToday && live != null
        ? 'DRY RUN until ${_dateName(live)}'
        : 'LIVE';
  }

  String _dayName(GameEvent e) {
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final d = DateTime(e.day.year, e.day.month, e.day.day);
    return '${names[d.weekday - 1]} ${e.day.day}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) tick();
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
