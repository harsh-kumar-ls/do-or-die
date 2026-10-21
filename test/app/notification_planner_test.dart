import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/app/notification_planner.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:flutter_test/flutter_test.dart';

const tasks = [
  TaskDefinition(
    id: 'breakfast',
    name: 'Have breakfast',
    type: TaskType.checkbox,
    target: 1,
  ),
  TaskDefinition(id: 'read', name: 'Read', type: TaskType.counter, target: 30),
];

void main() {
  const planner = NotificationPlanner();
  late FixedClock clock;

  setUp(() => clock = FixedClock(DateTime(2026, 10, 19, 10))); // Monday 10:00

  Future<GameService> start() => GameService.start(
    store: MemoryGameStore(),
    tasks: tasks,
    blockedPackages: const {'com.instagram.android'},
    clock: clock,
    random: Random(2),
  );

  PlannedNotice? byId(List<PlannedNotice> plan, int id) =>
      plan.where((n) => n.id == id).firstOrNull;

  test(
    'incomplete quest: warnings at 21:00 and 23:00 naming what is left',
    () async {
      final g = await start();
      await g.setProgress('breakfast', 1);
      final plan = planner.plan(g, clock.now());

      final w3 = byId(plan, NoticeId.warning3h)!;
      expect(w3.at, DateTime(2026, 10, 19, 21));
      expect(w3.body, contains('Read'));
      expect(w3.body, isNot(contains('Have breakfast')));
      expect(byId(plan, NoticeId.warning1h)!.at, DateTime(2026, 10, 19, 23));
    },
  );

  test('a complete quest cancels the warnings', () async {
    final g = await start();
    await g.setProgress('breakfast', 1);
    await g.setProgress('read', 30);
    final plan = planner.plan(g, clock.now());
    expect(byId(plan, NoticeId.warning3h), isNull);
    expect(byId(plan, NoticeId.warning1h), isNull);
  });

  test('a warning whose time has passed is not scheduled', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 19, 22));
    final plan = planner.plan(g, clock.now());
    expect(byId(plan, NoticeId.warning3h), isNull);
    expect(byId(plan, NoticeId.warning1h), isNotNull);
  });

  test(
    'morning notice at wake-up says "issued" when the quest is done',
    () async {
      final g = await start();
      await g.setProgress('breakfast', 1);
      await g.setProgress('read', 30);
      final morning = byId(planner.plan(g, clock.now()), NoticeId.morning)!;
      expect(morning.at, DateTime(2026, 10, 20, 7));
      expect(morning.title, contains('Daily quest issued'));
    },
  );

  test(
    'morning notice says "judgement pending" when the quest is incomplete',
    () async {
      final g = await start();
      final morning = byId(planner.plan(g, clock.now()), NoticeId.morning)!;
      expect(morning.title, contains('Judgement pending'));
    },
  );

  test('before wake-up, the morning notice is for later today', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 19, 5));
    final morning = byId(planner.plan(g, clock.now()), NoticeId.morning)!;
    expect(morning.at, DateTime(2026, 10, 19, 7));
    // Today's quest is simply starting; nothing is being judged yet.
    expect(morning.title, contains('Daily quest issued'));
  });

  test('after a failed day: exercise reminder at 20:00 and a notice exactly when the lock starts', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 20, 6)); // Monday failed
    await g.tick();
    final plan = planner.plan(g, clock.now());

    final exercise = byId(plan, NoticeId.exercise)!;
    expect(exercise.at, DateTime(2026, 10, 20, 20));
    expect(exercise.body, contains('50 push-ups'));

    final lock = g.state.lock!;
    final engaged = byId(plan, NoticeId.lockEngaged)!;
    expect(engaged.at, lock.start, reason: 'never announced before it starts');
  });

  test('paid exercise has no reminder', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 20, 6));
    await g.tick();
    await g.recordExercise(pushups: 50);
    expect(byId(planner.plan(g, clock.now()), NoticeId.exercise), isNull);
  });

  test('a lock that already started gets no "engaged" notice', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 20, 6));
    await g.tick();
    clock.set(g.state.lock!.start.add(const Duration(minutes: 1)));
    expect(byId(planner.plan(g, clock.now()), NoticeId.lockEngaged), isNull);
  });

  test('every planned notice is in the future and ids are unique', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 20, 6));
    await g.tick();
    final now = clock.now();
    final plan = planner.plan(g, now);
    expect(plan.every((n) => n.at.isAfter(now)), isTrue);
    expect(plan.map((n) => n.id).toSet().length, plan.length);
  });

  test(
    '"lock re-engaged" fires exactly when a release ends, with the count',
    () async {
      final g = await start();
      clock.set(DateTime(2026, 10, 20, 6));
      await g.tick();
      final lock = g.state.lock!;
      clock.set(lock.start.add(const Duration(minutes: 30)));
      await g.releaseLock();

      final notice = byId(
        planner.plan(g, clock.now()),
        NoticeId.lockReengaged,
      )!;
      expect(notice.at, lock.start.add(const Duration(minutes: 45)));
      expect(notice.body, contains('Releases used: 1 (15 min)'));
    },
  );

  test('no "re-engaged" notice if the lock ends during the release', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 20, 6));
    await g.tick();
    final lock = g.state.lock!;
    clock.set(lock.end.subtract(const Duration(minutes: 5)));
    await g.releaseLock();
    expect(byId(planner.plan(g, clock.now()), NoticeId.lockReengaged), isNull);
  });
}
