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
  final ExerciseDebt? debt;

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
    ExerciseDebt? Function()? debt,
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

class LevelUp extends GameEvent {
  const LevelUp(super.day, this.newLevel);
  final int newLevel;
}

class CarriedOver extends GameEvent {
  const CarriedOver(super.day, {required this.pushups, required this.squats});

  /// Reps added to the next day, after interest.
  final int pushups;
  final int squats;
}

class PenaltyIssued extends GameEvent {
  const PenaltyIssued(
    super.day, {
    required this.pushups,
    required this.squats,
    this.enforced = true,
  });

  /// The new penalty for the failed day, before any carry-over.
  final int pushups;
  final int squats;

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
  EngineResult closeDaysBefore({
    required GameState state,
    required DayKey today,
    required QuestPlan plan,
    required DayProgress Function(DayKey day) progressFor,
    required SleepWindow sleep,
    required Random random,
    required DateTime now,
    bool Function(DayKey failedDay) isEnforced = _always,
  }) {
    final events = <GameEvent>[];
    var s = state;
    while (s.nextDayToClose.isBefore(today)) {
      final day = s.nextDayToClose;
      s = _closeDay(
        s,
        day,
        plan.tasksFor(day),
        progressFor(day),
        sleep,
        random,
        now,
        isEnforced(day),
        events,
      );
    }
    return EngineResult(s, events);
  }

  static bool _always(DayKey _) => true;

  GameState _closeDay(
    GameState s,
    DayKey day,
    List<TaskDefinition> tasks,
    DayProgress progress,
    SleepWindow sleep,
    Random random,
    DateTime now,
    bool enforced,
    List<GameEvent> events,
  ) {
    final failedIds = [
      for (final t in tasks)
        if (!t.isComplete(progress[t.id] ?? 0)) t.id,
    ];
    final cleared = failedIds.isEmpty;

    var level = s.level;
    var xp = s.xp;
    var points = s.unspentStatPoints;

    // Penalty uses the level the player held on the failed day.
    final penaltyLevel = level;

    if (cleared) {
      xp += config.xpPerClear;
      events.add(QuestCleared(day, config.xpPerClear));
      while (xp >= progression.xpToNextLevel(level)) {
        xp -= progression.xpToNextLevel(level);
        level++;
        points += config.statPointsPerLevel;
        events.add(LevelUp(day, level));
      }
    } else {
      events.add(QuestFailed(day, failedIds));
    }

    // Carry-over: anything unpaid on a debt due today doubles into tomorrow.
    var carryPushups = 0;
    var carrySquats = 0;
    final debt = s.debt;
    if (debt != null && !debt.dueDay.isAfter(day) && !debt.isPaid) {
      carryPushups = debt.pushupsRemaining * config.carryOverMultiplier;
      carrySquats = debt.squatsRemaining * config.carryOverMultiplier;
      events.add(CarriedOver(day, pushups: carryPushups, squats: carrySquats));
    }

    var newPushups = 0;
    var newSquats = 0;
    LockWindow? lock = s.lock;
    final tomorrow = day.addDays(1);

    if (!cleared) {
      final pushups = penalties.pushupsForLevel(penaltyLevel);
      final squats = penalties.squatsForLevel(penaltyLevel);
      events.add(
        PenaltyIssued(
          day,
          pushups: pushups,
          squats: squats,
          enforced: enforced,
        ),
      );

      final window = scheduler.schedule(
        day: tomorrow,
        durationMinutes: penalties.lockMinutesForLevel(penaltyLevel),
        sleep: sleep,
        random: random,
        notBefore: now,
      );
      events.add(
        window == null
            ? LockMissed(tomorrow)
            : LockScheduled(tomorrow, window, enforced: enforced),
      );

      if (enforced) {
        newPushups = pushups;
        newSquats = squats;
        lock = window;
      }
    }

    final totalPushups = newPushups + carryPushups;
    final totalSquats = newSquats + carrySquats;
    final nextDebt = totalPushups + totalSquats > 0
        ? ExerciseDebt(
            dueDay: tomorrow,
            pushupsOwed: totalPushups,
            squatsOwed: totalSquats,
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

  /// Records exercise done on [today] against the debt due today.
  GameState recordExercise(
    GameState s,
    DayKey today, {
    int pushups = 0,
    int squats = 0,
  }) {
    final debt = s.debt;
    if (debt == null || debt.dueDay != today) return s;
    return s.copyWith(
      debt: () => debt.record(pushups: pushups, squats: squats),
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
