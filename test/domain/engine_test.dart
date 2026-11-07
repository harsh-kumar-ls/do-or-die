import 'dart:math';

import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/engine.dart';
import 'package:do_or_die/domain/penalty.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:flutter_test/flutter_test.dart';

const monday = DayKey(2026, 10, 19);
final tuesday = monday.addDays(1);
final wednesday = monday.addDays(2);

const tasks = [
  TaskDefinition(
    id: 'breakfast',
    name: 'Breakfast',
    type: TaskType.checkbox,
    target: 1,
  ),
  TaskDefinition(id: 'study', name: 'Study', type: TaskType.timer, target: 120),
  TaskDefinition(id: 'read', name: 'Read', type: TaskType.counter, target: 30),
];

const allDone = {'breakfast': 1, 'study': 7200, 'read': 30};
const oneMissed = {'breakfast': 1, 'study': 3600, 'read': 30};
const nothingDone = <String, int>{};

void main() {
  final engine = QuestEngine();
  final plan = QuestPlan.initial(monday, tasks);
  const sleep = SleepWindow();

  /// Closes all days before [today], using [progress] per day (default: nothing done).
  EngineResult close(
    GameState s,
    DayKey today, {
    Map<DayKey, DayProgress> progress = const {},
    QuestPlan? withPlan,
    DateTime? now,
  }) => engine.closeDaysBefore(
    state: s,
    today: today,
    plan: withPlan ?? plan,
    progressFor: (d) => progress[d] ?? nothingDone,
    sleep: sleep,
    random: Random(7),
    now: now ?? today.at(0),
  );

  test('a cleared day gives XP and no penalty', () {
    final r = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: allDone},
    );
    expect(r.state.xp, 100);
    expect(r.state.debt, isNull);
    expect(r.state.lock, isNull);
    expect(r.events.whereType<QuestCleared>(), hasLength(1));
  });

  test('missing one task fails the day: 10 push-ups, 15 squats and a lock on the next day', () {
    final r = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
    );
    final debt = r.state.debt!;
    expect(debt.dueDay, tuesday);
    expect(debt.primaryOwed, 10);
    expect(debt.secondaryOwed, 15);

    final lock = r.state.lock!;
    expect(lock.day, tuesday);
    expect(lock.duration, const Duration(hours: 4));
    expect(lock.start.isBefore(tuesday.at(7 * 60)), isFalse);
    expect(lock.end.isAfter(tuesday.at(23 * 60)), isFalse);

    final failed = r.events.whereType<QuestFailed>().single;
    expect(failed.failedTaskIds, ['study']);
    expect(r.state.xp, 0);
  });

  test(
    'failing all three tasks is still one penalty (per day, not per task)',
    () {
      final r = close(
        GameState.start(monday),
        tuesday,
        progress: {monday: nothingDone},
      );
      expect(r.state.debt!.primaryOwed, 10);
      expect(r.state.debt!.secondaryOwed, 15);
    },
  );

  test('unpaid reps expire at midnight: nothing carries, nothing doubles', () {
    var s = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
    ).state;
    s = engine.recordPenalty(s, tuesday, primary: 4);
    final r = close(
      s,
      wednesday,
      progress: {monday: oneMissed, tuesday: allDone},
    );

    expect(r.state.debt, isNull);
    final expired = r.events.whereType<PenaltyExpired>().single;
    expect(expired.primary, 6);
    expect(expired.secondary, 15);
  });

  test('a new failure owes only its own penalty, never the old one', () {
    var s = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
    ).state;
    s = engine.recordPenalty(s, tuesday, primary: 4);
    final r = close(
      s,
      wednesday,
      progress: {monday: oneMissed, tuesday: oneMissed},
    );
    expect(r.state.debt!.primaryOwed, 10);
    expect(r.state.debt!.secondaryOwed, 15);
  });

  test('an expired debt with a cleared day does not lock apps', () {
    var s = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
    ).state;
    final mondayLock = s.lock;
    final r = close(
      s,
      wednesday,
      progress: {monday: oneMissed, tuesday: allDone},
    );
    expect(r.events.whereType<LockScheduled>(), isEmpty);
    expect(
      r.state.lock,
      same(mondayLock),
      reason: 'only the old, finished lock remains',
    );
    expect(r.state.lock!.isActiveAt(wednesday.at(12 * 60)), isFalse);
  });

  test('paying the full debt leaves nothing to expire', () {
    var s = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
    ).state;
    s = engine.recordPenalty(s, tuesday, primary: 10, secondary: 15);
    final r = close(
      s,
      wednesday,
      progress: {monday: oneMissed, tuesday: allDone},
    );
    expect(r.state.debt, isNull);
    expect(r.events.whereType<PenaltyExpired>(), isEmpty);
  });

  test('a week of unpaid failures never owes more than one day', () {
    var s = GameState.start(monday);
    for (var i = 1; i <= 7; i++) {
      s = close(s, monday.addDays(i)).state;
      expect(s.debt!.primaryOwed, 10);
      expect(s.debt!.secondaryOwed, 15);
    }
  });

  test('the exercise penalty is the quest volume given for that day', () {
    final r = engine.closeDaysBefore(
      state: GameState.start(monday),
      today: tuesday,
      plan: plan,
      progressFor: (_) => oneMissed,
      sleep: sleep,
      random: Random(7),
      now: tuesday.at(0),
      exerciseFor: (_) => (20, 30),
      penaltyMultiplier: (_) => 2,
    );
    expect(r.state.debt!.primaryOwed, 20);
    expect(r.state.debt!.secondaryOwed, 30);
    expect(r.state.lock!.duration, const Duration(hours: 8));
  });

  test('exercise only counts on the day it is due', () {
    final s = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
    ).state;
    expect(engine.recordPenalty(s, monday, primary: 10).debt!.primaryDone, 0);
    expect(
      engine.recordPenalty(s, wednesday, primary: 10).debt!.primaryDone,
      0,
    );
    expect(engine.recordPenalty(s, tuesday, primary: 10).debt!.primaryDone, 10);
  });

  test('levelling up lengthens the lock but never the exercise', () {
    var s = GameState.start(monday);
    final progress = <DayKey, DayProgress>{};
    // Level 2 needs 300 XP: three cleared days.
    for (var i = 0; i < 3; i++) {
      progress[monday.addDays(i)] = allDone;
    }
    final failDay = monday.addDays(3);
    progress[failDay] = oneMissed;
    final r = close(s, failDay.addDays(1), progress: progress);
    s = r.state;

    expect(r.events.whereType<LevelUp>().single.newLevel, 2);
    expect(s.level, 2);
    expect(s.unspentStatPoints, 3);
    expect(s.debt!.primaryOwed, 10);
    expect(s.lock!.duration, const Duration(minutes: 240));
  });

  test('moving the clock backwards reopens nothing and changes nothing', () {
    final s = close(
      GameState.start(monday),
      wednesday,
      progress: {monday: oneMissed, tuesday: allDone},
    ).state;
    final r = close(s, monday, progress: {monday: allDone, tuesday: allDone});
    expect(r.events, isEmpty);
    expect(identical(r.state, s), isTrue);
    expect(s.isOpen(monday), isFalse);
    expect(s.isOpen(wednesday), isTrue);
  });

  test('progress entered after a day is closed cannot clear it', () {
    final s = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
    ).state;
    final again = close(s, tuesday, progress: {monday: allDone});
    expect(again.events, isEmpty);
    expect(again.state.debt!.primaryOwed, 10);
  });

  test('skipped days are each judged when the app catches up', () {
    final r = close(GameState.start(monday), monday.addDays(3));
    expect(r.events.whereType<QuestFailed>(), hasLength(3));
  });

  test('a late catch-up never schedules a lock in the past', () {
    // App opened at 20:00 Tuesday: Monday is judged late, only 3h of waking time left.
    final r = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
      now: tuesday.at(20 * 60),
    );
    final lock = r.state.lock!;
    expect(lock.start.isBefore(tuesday.at(20 * 60)), isFalse);
    expect(lock.clamped, isTrue);
  });

  test('edits apply from the next day, never the current one', () {
    final easier = [
      tasks[0],
      const TaskDefinition(
        id: 'study',
        name: 'Study',
        type: TaskType.timer,
        target: 60,
      ),
      tasks[2],
    ];
    final edited = plan.edit(monday, easier);
    expect(edited.tasksFor(monday)[1].target, 120);
    expect(edited.tasksFor(tuesday)[1].target, 60);

    // Monday with 60 minutes of study still fails under the edited plan.
    final r = close(
      GameState.start(monday),
      tuesday,
      progress: {monday: oneMissed},
      withPlan: edited,
    );
    expect(r.events.whereType<QuestFailed>(), hasLength(1));
  });

  test('stat points can be allocated, but not below zero', () {
    var s = const GameState(startDay: monday, unspentStatPoints: 1);
    s = engine.allocateStat(s, Stat.intellect);
    s = engine.allocateStat(s, Stat.intellect);
    expect(s.stats[Stat.intellect], 1);
    expect(s.unspentStatPoints, 0);
  });

  test('rank changes every 10 levels', () {
    expect(engine.progression.rankForLevel(1), Rank.e);
    expect(engine.progression.rankForLevel(10), Rank.d);
    expect(engine.progression.rankForLevel(50), Rank.s);
  });
}
