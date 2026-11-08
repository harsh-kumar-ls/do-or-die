import 'dart:math';

import 'config.dart';
import 'day.dart';
import 'penalty.dart';
import 'progression.dart';
import 'tasks.dart';

/// Everything the game knows about the player at a point in time.
class GameState {
  const GameState({
    required this.startDay,
    this.lastClosedDay,
    this.level = 1,
    this.xp = 0,
    this.unspentStatPoints = 0,
    this.stats = const {},
    this.debt,
    this.lock,
  });

  factory GameState.start(DayKey startDay) => GameState(startDay: startDay);

  /// The first day with a quest.
  final DayKey startDay;

  /// The most recent day whose quest has been judged. Days up to and
  /// including this one can no longer change.
  final DayKey? lastClosedDay;

  final int level;
  final int xp;
  final int unspentStatPoints;
  final Map<Stat, int> stats;

  /// Exercise currently owed, if any.
  final PenaltyDebt? debt;

  /// The scheduled or running app lock, if any.
  final LockWindow? lock;

  DayKey get nextDayToClose => lastClosedDay?.addDays(1) ?? startDay;

  /// Whether progress for [day] may still be recorded.
  bool isOpen(DayKey day) => !day.isBefore(nextDayToClose);

  GameState copyWith({
    DayKey? lastClosedDay,
    int? level,
    int? xp,
    int? unspentStatPoints,
    Map<Stat, int>? stats,
    PenaltyDebt? Function()? debt,
    LockWindow? Function()? lock,
  }) => GameState(
    startDay: startDay,
    lastClosedDay: lastClosedDay ?? this.lastClosedDay,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    unspentStatPoints: unspentStatPoints ?? this.unspentStatPoints,
    stats: stats ?? this.stats,
    debt: debt != null ? debt() : this.debt,
    lock: lock != null ? lock() : this.lock,
  );
}

/// Something that happened, for the trial log.
sealed class GameEvent {
  const GameEvent(this.day);
  final DayKey day;
}

class QuestCleared extends GameEvent {
  const QuestCleared(super.day, this.xpGained);
  final int xpGained;
}

class QuestFailed extends GameEvent {
  const QuestFailed(super.day, this.failedTaskIds);
  final List<String> failedTaskIds;
}

/// Most of the quest was done (see [GameConfig.nearMissPercent]): no
/// penalty and no lock, but no XP, and it doesn't count toward a Gate.
class QuestNearMiss extends GameEvent {
  const QuestNearMiss(super.day, this.failedTaskIds, this.percentDone);
  final List<String> failedTaskIds;
  final int percentDone;
}

class LevelUp extends GameEvent {
  const LevelUp(super.day, this.newLevel);
  final int newLevel;
}

/// A penalty left unpaid at the end of its day. It is dropped and logged:
/// nothing carries over and nothing doubles (audit 2026-11-07, P0).
class PenaltyExpired extends GameEvent {
  const PenaltyExpired(
    super.day, {
    required this.primary,
    required this.secondary,
    this.kind = PenaltyKind.exercise,
  });

  /// What was still unpaid when the day ended.
  final int primary;
  final int secondary;
  final PenaltyKind kind;
}

class PenaltyIssued extends GameEvent {
  const PenaltyIssued(
    super.day, {
    required this.primary,
    required this.secondary,
    this.kind = PenaltyKind.exercise,
    this.enforced = true,
  });

  /// The new penalty for the failed day, before any carry-over.
  final int primary;
  final int secondary;
  final PenaltyKind kind;

  /// False during a dry run: worked out and shown, but not owed.
  final bool enforced;
}

class LockScheduled extends GameEvent {
  const LockScheduled(super.day, this.window, {this.enforced = true});
  final LockWindow window;

  /// False during a dry run: the window is shown, but nothing is locked.
  final bool enforced;
}

class LockMissed extends GameEvent {
  const LockMissed(super.day);
}

class EngineResult {
  const EngineResult(this.state, this.events);
  final GameState state;
  final List<GameEvent> events;
}

class QuestEngine {
  QuestEngine({
    this.config = const GameConfig(),
    this.scheduler = const LockScheduler(),
  }) : penalties = PenaltyCalculator(config),
       progression = Progression(config);

  final GameConfig config;
  final LockScheduler scheduler;
  final PenaltyCalculator penalties;
  final Progression progression;

  /// Judges every day before [today] that has not been judged yet.
  ///
  /// Days are only ever closed going forward: if the clock moves backwards,
  /// nothing is reopened or recalculated.
  ///
  /// [isEnforced] decides, per failed day, whether its penalty is real. A
  /// dry-run day still gets the full penalty and lock window worked out and
  /// reported, but nothing is owed and nothing is locked.
  ///
  /// [tasksFor], when given, replaces [plan] as the source of each day's
  /// quest (System games). [penaltyMultiplier] scales a failed day's lock
  /// and its reading or focus penalty (2 on a Dungeon floor), never its
  /// exercise; [xpPercent] scales its XP. [exerciseFor] gives the push-ups
  /// and squats in that day's own quest, which bound the exercise penalty.
  EngineResult closeDaysBefore({
    required GameState state,
    required DayKey today,
    required QuestPlan plan,
    required DayProgress Function(DayKey day) progressFor,
    List<TaskDefinition> Function(DayKey day)? tasksFor,
    required SleepWindow sleep,
    required Random random,
    required DateTime now,
    bool Function(DayKey failedDay) isEnforced = _always,
    int Function(DayKey day) penaltyMultiplier = _one,
    int Function(DayKey day) xpPercent = _hundred,
    PenaltyKind Function(DayKey day) penaltyKind = _exercise,
    (int, int)? Function(DayKey day)? exerciseFor,
    int? lockStartMinute,
    bool Function(DayKey day) nearMissAllowed = _always,
  }) {
    final events = <GameEvent>[];
    var s = state;
    while (s.nextDayToClose.isBefore(today)) {
      final day = s.nextDayToClose;
      s = _closeDay(
        s,
        day,
        tasksFor != null ? tasksFor(day) : plan.tasksFor(day),
        progressFor(day),
        sleep,
        random,
        now,
        isEnforced(day),
        penaltyMultiplier(day),
        xpPercent(day),
        penaltyKind(day),
        exerciseFor?.call(day),
        lockStartMinute,
        nearMissAllowed(day),
        events,
      );
    }
    return EngineResult(s, events);
  }

  static bool _always(DayKey _) => true;
  static int _one(DayKey _) => 1;
  static int _hundred(DayKey _) => 100;
  static PenaltyKind _exercise(DayKey _) => PenaltyKind.exercise;

  GameState _closeDay(
    GameState s,
    DayKey day,
    List<TaskDefinition> tasks,
    DayProgress progress,
    SleepWindow sleep,
    Random random,
    DateTime now,
    bool enforced,
    int multiplier,
    int xpPercent,
    PenaltyKind kind,
    (int, int)? exercise,
    int? lockStartMinute,
    bool nearMissAllowed,
    List<GameEvent> events,
  ) {
    final failedIds = [
      for (final t in tasks)
        if (!t.isComplete(progress[t.id])) t.id,
    ];
    final cleared = failedIds.isEmpty;
    final percentDone = tasks.isEmpty
        ? 0
        : (100 *
                  tasks.fold<double>(
                    0,
                    (a, t) => a + t.completion(progress[t.id]),
                  ) /
                  tasks.length)
              .floor();
    final nearMiss =
        !cleared && nearMissAllowed && percentDone >= config.nearMissPercent;

    var level = s.level;
    var xp = s.xp;
    var points = s.unspentStatPoints;

    // Penalty uses the level the player held on the failed day.
    final penaltyLevel = level;

    if (cleared) {
      final gained = config.xpPerClear * xpPercent ~/ 100;
      xp += gained;
      events.add(QuestCleared(day, gained));
      while (xp >= progression.xpToNextLevel(level)) {
        xp -= progression.xpToNextLevel(level);
        level++;
        points += config.statPointsPerLevel;
        events.add(LevelUp(day, level));
      }
    } else if (nearMiss) {
      events.add(QuestNearMiss(day, failedIds, percentDone));
    } else {
      events.add(QuestFailed(day, failedIds));
    }

    // A debt due on or before this day ends with it: anything unpaid is
    // logged and dropped, never carried or doubled.
    final debt = s.debt;
    if (debt != null && !debt.dueDay.isAfter(day) && !debt.isPaid) {
      events.add(
        PenaltyExpired(
          day,
          primary: debt.primaryRemaining,
          secondary: debt.secondaryRemaining,
          kind: debt.kind,
        ),
      );
    }

    var newPrimary = 0;
    var newSecondary = 0;
    LockWindow? lock = s.lock;
    final tomorrow = day.addDays(1);

    if (!cleared && !nearMiss) {
      // A failed Dungeon floor doubles a reading or focus penalty; the lock
      // stays its normal length and exercise its own quest volume.
      final (primary, secondary) = penalties.amountsFor(
        kind,
        penaltyLevel,
        multiplier: multiplier,
        exercise: exercise,
      );
      events.add(
        PenaltyIssued(
          day,
          primary: primary,
          secondary: secondary,
          kind: kind,
          enforced: enforced,
        ),
      );

      final window = scheduler.schedule(
        day: tomorrow,
        durationMinutes: penalties.lockMinutesForLevel(penaltyLevel),
        sleep: sleep,
        random: random,
        notBefore: now,
        startMinute: lockStartMinute,
      );
      events.add(
        window == null
            ? LockMissed(tomorrow)
            : LockScheduled(tomorrow, window, enforced: enforced),
      );

      if (enforced) {
        newPrimary = primary;
        newSecondary = secondary;
        lock = window;
      }
    }

    final nextDebt = newPrimary + newSecondary > 0
        ? PenaltyDebt(
            dueDay: tomorrow,
            kind: kind,
            primaryOwed: newPrimary,
            secondaryOwed: newSecondary,
          )
        : null;

    return s.copyWith(
      lastClosedDay: day,
      level: level,
      xp: xp,
      unspentStatPoints: points,
      debt: () => nextDebt,
      lock: () => lock,
    );
  }

  /// Records penalty work done on [today] against the debt due today.
  GameState recordPenalty(
    GameState s,
    DayKey today, {
    int primary = 0,
    int secondary = 0,
  }) {
    final debt = s.debt;
    if (debt == null || debt.dueDay != today) return s;
    return s.copyWith(
      debt: () => debt.record(primary: primary, secondary: secondary),
    );
  }

  GameState allocateStat(GameState s, Stat stat) {
    if (s.unspentStatPoints <= 0) return s;
    return s.copyWith(
      unspentStatPoints: s.unspentStatPoints - 1,
      stats: {...s.stats, stat: (s.stats[stat] ?? 0) + 1},
    );
  }
}
