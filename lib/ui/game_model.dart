import 'dart:math';
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
import '../domain/penalty.dart';
import '../domain/progression.dart';
import '../domain/system_catalogue.dart';
import '../domain/systems.dart';
import '../domain/tasks.dart';
import 'fx.dart';

/// The kinds of System notice, each with its own look and entrance
/// (design/claude-design/notices.html).
enum NoticeKind {
  cleared,
  levelUp,
  warning,
  dryRun,
  gate,
  rankUp,
  dungeonFailed,
  complete,
  info,
}

enum RowTone { plain, ok, bad, gold }

class NoticeRow {
  const NoticeRow(this.label, this.value, [this.tone = RowTone.plain]);
  final String label;
  final String value;
  final RowTone tone;
}

/// A System notice waiting to be shown.
class SystemNotice {
  const SystemNotice({
    this.kind = NoticeKind.info,
    required this.title,
    this.kicker = '',
    this.lines = const [],
    this.rows = const [],
    this.note,
    this.xp,
    this.xpFrom,
    this.xpMax,
    this.level,
    this.points,
    this.stats = const [],
    this.rankFrom,
    this.rankTo,
    this.rankTitle,
    this.closesAt,
    this.cue,
  });

  final NoticeKind kind;
  final String title;
  final String kicker;
  final List<String> lines;
  final List<NoticeRow> rows;
  final String? note;

  /// QUEST CLEARED: the reward, and the bar it fills.
  final int? xp;
  final int? xpFrom;
  final int? xpMax;

  /// LEVEL UP: the new level, points and the stats they suit.
  final int? level;
  final int? points;
  final List<String> stats;

  /// RANK UP and GATE.
  final Rank? rankFrom;
  final Rank? rankTo;
  final String? rankTitle;
  final DateTime? closesAt;

  /// Overrides the default sound for this notice.
  final Cue? cue;

  bool get danger =>
      kind == NoticeKind.warning || kind == NoticeKind.dungeonFailed;

  /// Order within one batch: failures first, then the rewards, then what
  /// opens next.
  int get priority => switch (kind) {
    NoticeKind.warning || NoticeKind.dungeonFailed || NoticeKind.dryRun => 0,
    NoticeKind.cleared => 1,
    NoticeKind.levelUp => 2,
    NoticeKind.rankUp => 3,
    NoticeKind.info => 4,
    NoticeKind.gate || NoticeKind.complete => 5,
  };

  Cue get sound =>
      cue ??
      switch (kind) {
        NoticeKind.cleared => Cue.confirm,
        NoticeKind.levelUp => Cue.levelUp,
        NoticeKind.warning => Cue.penalty,
        NoticeKind.gate => Cue.gateOpen,
        NoticeKind.rankUp || NoticeKind.complete => Cue.rankUp,
        NoticeKind.dungeonFailed => Cue.dungeonPenalty,
        NoticeKind.dryRun || NoticeKind.info => Cue.notice,
      };
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

  /// A watcher found off whose last heartbeat is this recent was only
  /// restarting (the app process starting, or an update), not down.
  static const outageGrace = Duration(seconds: 60);

  /// Checks the blocker service is still on. If it was switched off (a force
  /// stop does this), restarts it, and logs one incident per real outage
  /// with how long the watcher was down.
  Future<void> _watchBlocker() async {
    final blocker = enforcer?.blocker;
    if (blocker == null || !blocker.canBlock) return;
    try {
      var status = await blocker.systemStatus();
      if (!status.serviceEnabled) {
        final permitted = status.usageAccess && status.overlay;
        final since = permitted ? status.lastHeartbeatAt : null;
        final brief =
            since != null && service.now.difference(since) < outageGrace;
        // A force stop kills the watcher; restarting it needs no special
        // permission, only the two the user already granted.
        final repaired = await blocker.startWatcher();
        if (_blockerWasOn != false && !brief) {
          await service.recordBlockerOffline(
            repaired: repaired,
            downSince: since,
          );
        }
        if (repaired) status = await blocker.systemStatus();
      }
      _blockerWasOn = status.serviceEnabled;
      system = status;
      final failed = status.lastStartFailureAt;
      if (failed != null) await service.recordWatcherStartFailure(failed);
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
      !s.autoTimeZone,
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

  /// "NOTICE 2 / 3" while a batch of several is showing; empty otherwise.
  String get noticeCounter =>
      _batch > 1 ? 'NOTICE ${_batch - _notices.length + 1} / $_batch' : '';
  int _batch = 0;

  void dismissNotice() {
    if (_notices.isEmpty) return;
    _notices.removeAt(0);
    if (_notices.isEmpty) _batch = 0;
    notifyListeners();
  }

  GameState get state => service.state;

  /// The simple game: no levels, XP or stat points on screen; ranks come
  /// from milestones.
  bool get simple => service.game.simple;

  /// Cleared days needed for the next rank (milestone or Gate).
  int get nextRankNeeds {
    final r = rank;
    return simple ? SystemsState.milestoneFor(r) : DungeonRules.clearedNeeded;
  }

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
  int get reducedDaysLeft => service.reducedDaysLeft;
  bool get reductionLimitedTomorrow => service.reductionLimitedTomorrow;

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

  /// A lock is scheduled for today but hasn't started (at the time the user
  /// chose).
  bool get lockPending {
    final lock = state.lock;
    if (lock == null || lock.day != service.today || lock.cancelled) {
      return false;
    }
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
          kicker: 'SYSTEM',
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

  /// Pushes everything to the phone's blocker again (after diagnostics or
  /// anything else that changed it behind the enforcer's back).
  Future<void> resyncBlocker() async {
    enforcer?.invalidate();
    await _sync();
  }

  /// False when refused (fewer than 12 waking hours).
  Future<bool> setSleepWindow(SleepWindow sleep) async {
    var ok = false;
    await _run(() async => ok = await service.setSleepWindow(sleep));
    return ok;
  }

  Future<void> setLockStart(int minute) =>
      _run(() => service.setLockStart(minute));

  Future<void> addBlockedApp(String package) =>
      _run(() => service.addBlockedApp(package));

  /// False when refused: the last app can't leave the lock list.
  Future<bool> removeBlockedApp(String package) async {
    var ok = false;
    await _run(() async => ok = await service.removeBlockedApp(package));
    return ok;
  }

  /// Apps that will no longer be locked from tomorrow.
  Set<String> get pendingUnblocks => service.blockedToday.difference(
    service.game.blockList.packagesOn(service.removalEffectiveFrom),
  );

  /// Takes a 15-minute release from the running lock. Returns false if the
  /// lock isn't in force right now.
  Future<bool> releaseLock() async {
    var released = false;
    await _run(() async => released = await service.releaseLock());
    return released;
  }

  /// Ends the lock now (always available; logged with [reason]).
  Future<bool> emergencyExit(String reason) async {
    var ok = false;
    await _run(() async => ok = await service.emergencyExit(reason: reason));
    return ok;
  }

  /// Contests yesterday's failed verdict (one in any 14 days).
  Future<bool> contestVerdict(String reason) async {
    var ok = false;
    await _run(() async => ok = await service.contestVerdict(reason));
    return ok;
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
    if (service.verdictPending && !service.penaltyInEffect) {
      return "Restart unlocks after tonight's verdict.";
    }
    if (!service.penaltyInEffect) return null;
    final parts = <String>[];
    final debt = state.debt;
    if (debt != null && debt.dueDay == service.today && !debt.isPaid) {
      parts.add(
        describePenalty(
          debt.kind,
          debt.primaryRemaining,
          debt.secondaryRemaining,
        ),
      );
    }
    final lock = state.lock;
    final lockLeft = lock != null && lock.effectiveEnd.isAfter(now);
    final owes = parts.isNotEmpty;
    if (owes && lockLeft) {
      return "Finish today's ${parts.single} and wait for today's lock to end to unlock restart.";
    }
    if (owes) return "Finish today's ${parts.single} to unlock restart.";
    if (lockLeft && lock.inWindowAt(now)) {
      return "Restart unlocks when today's lock ends at ${_hm(lock.effectiveEnd)}.";
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

  Future<void> recordPenalty({int primary = 0, int secondary = 0}) {
    Fx.instance.play(Cue.rep);
    return _run(
      () => service.recordPenalty(primary: primary, secondary: secondary),
    );
  }

  Future<bool> submitReflection(String text) async {
    var ok = false;
    await _run(() async => ok = await service.submitReflection(text));
    if (ok) Fx.instance.play(Cue.confirm);
    return ok;
  }

  /// A Focus penalty block: running, and how long.
  bool get penaltyBlockRunning => service.penaltyBlockRunning;
  int get penaltyBlockSeconds => service.penaltyBlockSeconds;

  Future<void> togglePenaltyBlock() {
    final running = service.penaltyBlockRunning;
    Fx.instance.play(running ? Cue.timerStop : Cue.timerStart);
    return _run(
      () => running ? service.stopTimer() : service.startPenaltyBlock(),
    );
  }

  Future<void> allocateStat(Stat stat) {
    if (state.unspentStatPoints > 0) Fx.instance.play(Cue.confirm);
    return _run(() => service.allocateStat(stat));
  }

  /// Queues notices; a batch is sorted so failures come first. Each plays
  /// its sound when it appears (see NoticeOverlay).
  void _queueAll(List<SystemNotice> batch) {
    if (batch.isEmpty) return;
    batch.sort((a, b) => a.priority.compareTo(b.priority));
    if (_notices.isEmpty) _batch = 0;
    _notices.addAll(batch);
    _batch += batch.length;
  }

  void _queue(SystemNotice n) => _queueAll([n]);

  /// Running timers can complete a task without any tap, so check on every
  /// rebuild tick too.
  void checkCompletion() {
    if (_checkCompletion()) notifyListeners();
  }

  /// The day whose completion was already announced in-app, so the verdict
  /// at midnight doesn't announce it twice.
  DayKey? _announced;

  bool _checkCompletion() {
    final complete = isQuestComplete;
    final changed = complete && !_wasComplete;
    _wasComplete = complete;
    if (changed) {
      _announced = service.today;
      final goals = tasks.where((t) => !t.isCap).length;
      _queue(
        SystemNotice(
          kind: NoticeKind.cleared,
          title: floorToday > 0
              ? '[ FLOOR $floorToday CLEARED ]'
              : '[ QUEST CLEARED ]',
          kicker: floorToday > 0 ? 'DUNGEON' : 'DAILY QUEST',
          xp: xpReward,
          xpFrom: state.xp,
          xpMax: xpToNext,
          rows: [
            NoticeRow('Objectives', '$goals / $goals'),
            if (floorToday > 0)
              NoticeRow('Dungeon progress', 'Floor $floorToday / 3')
            else if (systems != null)
              NoticeRow(
                'Days cleared',
                '${clearedInWindow + 1} / ${DungeonRules.clearedNeeded} for the Gate',
              ),
            NoticeRow(
              floorToday > 0 ? 'Dungeon Penalty' : 'Lockdown',
              'Avoided',
              RowTone.ok,
            ),
          ],
          note: 'The reward is granted at 00:00.',
        ),
      );
    }
    return changed;
  }

  void _drainSystemEvents() =>
      _queueAll(_systemNotices(service.takeSystemEvents()));

  static const _statShort = {
    Stat.strength: 'STR',
    Stat.intellect: 'INT',
    Stat.discipline: 'DIS',
    Stat.vitality: 'VIT',
    Stat.charisma: 'CHA',
  };

  void _noticesFor(List<GameEvent> events, List<SystemEvent> systemEvents) {
    final batch = <SystemNotice>[];
    // A failed floor gets the Dungeon notice instead of the ordinary one.
    final failedFloors = {
      for (final e in systemEvents.whereType<DungeonFailed>()) e.day,
    };
    for (final e in events) {
      if (e is QuestFailed && failedFloors.contains(e.day)) continue;
      switch (e) {
        case QuestCleared(:final xpGained):
          if (e.day == _announced) break;
          batch.add(
            SystemNotice(
              kind: NoticeKind.cleared,
              title: '[ QUEST CLEARED ]',
              kicker: _dayName(e),
              xp: xpGained,
              xpFrom: max(0, state.xp - xpGained),
              xpMax: xpToNext,
              rows: const [NoticeRow('Lockdown', 'Avoided', RowTone.ok)],
              note: 'Reward granted.',
            ),
          );
        case QuestNearMiss(:final percentDone, :final failedTaskIds):
          batch.add(
            SystemNotice(
              kind: NoticeKind.info,
              title: '[ NEAR MISS ]',
              kicker: _dayName(e),
              lines: [
                '$percentDone% of the quest was done.',
                'No penalty. No reward. It does not count toward the next rank.',
                if (service.nearMissStreak >= 3)
                  'Three near misses in a row. Lower the quest by 10-20% in '
                      'Status and clear it in full.',
              ],
              rows: [
                NoticeRow('Objectives missed', '${failedTaskIds.length}'),
                const NoticeRow('Lockdown', 'Not entered', RowTone.ok),
              ],
            ),
          );
        case LevelUp(:final newLevel):
          if (simple) break; // levels are not shown in the simple game
          batch.add(
            SystemNotice(
              kind: NoticeKind.levelUp,
              title: '[ LEVEL UP ]',
              kicker: 'PLAYER',
              level: newLevel,
              points: service.engine.config.statPointsPerLevel,
              stats: [
                for (final st in systemSpec?.stats ?? const <Stat>[])
                  _statShort[st]!,
              ],
              rows: [NoticeRow('Next level', '${state.xp} / $xpToNext XP')],
              note: 'Allocate them in STATUS.',
            ),
          );
        case QuestFailed(:final failedTaskIds):
          final penalty = events
              .whereType<PenaltyIssued>()
              .where((p) => p.day == e.day)
              .firstOrNull;
          final lock = events
              .whereType<LockScheduled>()
              .where((l) => l.day == e.day.addDays(1))
              .firstOrNull;
          final owed =
              penalty == null || penalty.primary + penalty.secondary == 0
              ? null
              : describePenalty(
                  penalty.kind,
                  penalty.primary,
                  penalty.secondary,
                );
          final hours = lock == null
              ? null
              : (lock.window.end.difference(lock.window.start).inMinutes / 60)
                    .round();
          if (penalty != null && !penalty.enforced) {
            final live = service.liveFrom;
            batch.add(
              SystemNotice(
                kind: NoticeKind.dryRun,
                title: '[ DRY RUN ]',
                kicker: _dayName(e),
                lines: const [
                  'The daily quest was not completed.',
                  'Dry run: nothing is enforced.',
                ],
                rows: [
                  NoticeRow('Objectives missed', '${failedTaskIds.length}'),
                  if (lock != null)
                    NoticeRow(
                      'Lock that would apply',
                      '${_hm(lock.window.start)} – ${_hm(lock.window.end)}',
                    ),
                  if (owed != null) NoticeRow('Debt that would apply', owed),
                ],
                note: live == null
                    ? null
                    : 'Penalties go live on ${_dateName(live)}.',
              ),
            );
          } else {
            batch.add(
              SystemNotice(
                kind: NoticeKind.warning,
                title: '[ WARNING ]',
                kicker: _dayName(e),
                lines: const [
                  'The daily quest was not completed.',
                  'The Lockdown is now active.',
                ],
                rows: [
                  NoticeRow('Objectives missed', '${failedTaskIds.length}'),
                  if (hours != null)
                    NoticeRow(
                      'App lock',
                      '$hours h · from ${_hm(lock!.window.start)}',
                      RowTone.bad,
                    ),
                  if (owed != null) NoticeRow('Penalty debt', owed),
                ],
                note: 'Clear the debt in PENALTY.',
              ),
            );
          }
        default:
          break;
      }
    }
    batch.addAll(_systemNotices(systemEvents, events));
    _queueAll(batch);
  }

  static String _r(Rank r) => r.name.toUpperCase();

  List<SystemNotice> _systemNotices(
    List<SystemEvent> events, [
    List<GameEvent> gameEvents = const [],
  ]) {
    return [
      for (final e in events)
        switch (e) {
          GateOpened(:final gate) => SystemNotice(
            kind: NoticeKind.gate,
            title: '[ GATE ]',
            kicker: 'GATE DETECTED',
            rankFrom: gate.from,
            rankTo: Rank.values[min(gate.from.index + 1, Rank.s.index)],
            closesAt: gate.expiresAt,
            lines: [
              'A Gate has opened.',
              'Rank ${_r(gate.from)} Dungeon.',
              'Enter within 48 hours.',
            ],
            rows: [
              const NoticeRow('Dungeon', '3 days · 3 floors'),
              NoticeRow(
                'Floor 3',
                'Rank Trial ${_r(gate.from)} → ${_r(Rank.values[min(gate.from.index + 1, Rank.s.index)])}',
              ),
            ],
          ),
          GateExpired() => const SystemNotice(
            title: '[ NOTIFICATION ]',
            kicker: 'GATE',
            lines: ['The Gate has closed.', 'It may open again in 3 days.'],
          ),
          DungeonEntered() => const SystemNotice(
            title: '[ DUNGEON ]',
            kicker: 'GATE ENTERED',
            cue: Cue.gateOpen,
            lines: ['You have entered the Dungeon.'],
            rows: [
              NoticeRow('Floor 1', 'Tomorrow · +25%'),
              NoticeRow('Floor 2', '+50% · by 18:00'),
              NoticeRow('Floor 3', 'Rank Trial'),
            ],
          ),
          FloorCleared(:final floor) => SystemNotice(
            title: '[ FLOOR $floor CLEARED ]',
            kicker: 'DUNGEON',
            lines: [
              floor == 1
                  ? 'Floor 2 begins. Clear it by 18:00.'
                  : 'The Rank Trial begins.',
            ],
          ),
          DungeonCleared(:final newRank, :final title) => SystemNotice(
            kind: NoticeKind.rankUp,
            title: '[ RANK UP ]',
            kicker: 'RANK TRIAL CLEARED',
            rankFrom: Rank.values[max(0, newRank.index - 1)],
            rankTo: newRank,
            rankTitle: title,
            points: DungeonRules.clearStatPoints,
            note: 'Rank ${_r(newRank)} quests begin tomorrow.',
          ),
          RankEarned(:final newRank, :final title) => SystemNotice(
            kind: NoticeKind.rankUp,
            title: '[ RANK UP ]',
            kicker: 'MILESTONE REACHED',
            rankFrom: Rank.values[max(0, newRank.index - 1)],
            rankTo: newRank,
            rankTitle: title,
            note: 'Rank ${_r(newRank)} quests begin tomorrow.',
          ),
          DungeonFailed(:final floor) => _dungeonFailed(e, floor, gameEvents),
          SystemCompleted(:final system) => SystemNotice(
            kind: NoticeKind.complete,
            title: '[ SYSTEM COMPLETE ]',
            kicker: 'SYSTEM',
            lines: [
              'The ${systemCatalogue[system]!.name} is complete.',
              'Rank S reached.',
            ],
            rows: [
              NoticeRow('Days held at S', '${SystemsState.catalogueHoldDays}'),
              NoticeRow(
                'Dungeons cleared',
                '${service.game.log.where((l) => l.type == 'dungeon_cleared').length}',
              ),
            ],
            note: 'You may now bind a new System.',
          ),
        },
    ];
  }

  SystemNotice _dungeonFailed(
    SystemEvent e,
    int floor,
    List<GameEvent> gameEvents,
  ) {
    final penalty = gameEvents
        .whereType<PenaltyIssued>()
        .where((p) => p.day == e.day)
        .firstOrNull;
    final lock = gameEvents
        .whereType<LockScheduled>()
        .where((l) => l.day == e.day.addDays(1))
        .firstOrNull;
    final dry = penalty != null && !penalty.enforced;
    return SystemNotice(
      kind: NoticeKind.dungeonFailed,
      title: '[ DUNGEON FAILED ]',
      kicker: 'DUNGEON',
      lines: [
        'Floor $floor was not cleared.',
        dry
            ? 'Dry run: no penalty is enforced.'
            : 'Dungeon Penalty today. The Gate is shut for 7 days.',
      ],
      rows: [
        if (lock != null)
          NoticeRow(
            'App lock',
            '${(lock.window.end.difference(lock.window.start).inMinutes / 60).round()} h · from ${_hm(lock.window.start)}',
            RowTone.bad,
          ),
        if (penalty != null && penalty.primary + penalty.secondary > 0)
          NoticeRow(
            'Penalty debt',
            // Exercise is never doubled: it stays at the daily quest.
            '${penalty.kind == PenaltyKind.exercise ? '' : '×2 · '}'
                '${describePenalty(penalty.kind, penalty.primary, penalty.secondary)}',
            RowTone.bad,
          ),
        NoticeRow('Rank', '${_r(rank)} · kept', RowTone.gold),
      ],
      note: 'The Gate is shut for ${DungeonRules.failCooldown} days.',
    );
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
