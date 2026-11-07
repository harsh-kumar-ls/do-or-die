import 'dart:convert';
import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/data/saved_game.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/engine.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:flutter_test/flutter_test.dart';

const tasks = [
  TaskDefinition(id: 'read', name: 'Read', type: TaskType.counter, target: 30),
];
const insta = 'com.instagram.android';

void main() {
  late MemoryGameStore store;
  late FixedClock clock;

  setUp(() {
    store = MemoryGameStore();
    clock = FixedClock(DateTime(2026, 10, 19, 10)); // Monday 10:00, day 1
  });

  Future<GameService> start({int dryRunDays = 3}) => GameService.start(
    store: store,
    tasks: tasks,
    blockedPackages: const {insta},
    dryRunDays: dryRunDays,
    clock: clock,
    random: Random(4),
  );

  test(
    'a failed dry-run day is judged and logged, but nothing is owed or locked',
    () async {
      final g = await start();
      clock.set(DateTime(2026, 10, 20, 8)); // Monday failed
      final events = await g.tick();

      expect(events.whereType<QuestFailed>(), hasLength(1));
      final penalty = events.whereType<PenaltyIssued>().single;
      expect(penalty.primary, 10);
      expect(penalty.enforced, isFalse);
      final lock = events.whereType<LockScheduled>().single;
      expect(lock.enforced, isFalse);
      expect(lock.window.duration, const Duration(hours: 4));

      expect(g.state.debt, isNull);
      expect(g.state.lock, isNull);
      expect(g.penaltyInEffect, isFalse);

      final logged = g.game.log.lastWhere((e) => e.type == 'penalty_issued');
      expect(logged.data['enforced'], isFalse);
    },
  );

  test('the first live day (day 4) is fully enforced', () async {
    final g = await start();
    expect(g.liveFrom, const DayKey(2026, 10, 22));
    expect(g.isDryRunToday, isTrue);

    // Days 1-3 cleared, then day 4 (Thursday) failed.
    for (var d = 0; d < 3; d++) {
      await g.addProgress('read', 30);
      clock.advance(const Duration(days: 1));
      await g.tick();
    }
    expect(g.trialDay, 4);
    expect(g.isDryRunToday, isFalse);

    clock.advance(const Duration(days: 1));
    final events = await g.tick();
    expect(events.whereType<PenaltyIssued>().single.enforced, isTrue);
    expect(g.state.debt!.primaryOwed, 10);
    expect(g.state.lock, isNotNull);
  });

  test('dry-run failures never leave a debt behind', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 21, 8)); // Monday and Tuesday both failed
    await g.tick();
    expect(g.state.debt, isNull);
    expect(g.game.log.where((e) => e.type == 'penalty_expired'), isEmpty);
  });

  test(
    'a game saved before dry-run mode existed stays fully enforced',
    () async {
      final g = await start(dryRunDays: 0);
      final json = g.game.toJson()..remove('liveFrom');
      final old = SavedGame.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, Object?>,
      );
      expect(old.liveFrom, isNull);
      expect(old.isEnforced(const DayKey(2026, 10, 19)), isTrue);

      await store.save(old);
      clock.set(DateTime(2026, 10, 20, 8));
      final reloaded = (await GameService.load(
        store: store,
        clock: clock,
        random: Random(4),
      ))!;
      expect(reloaded.state.debt!.primaryOwed, 10);
      expect(reloaded.state.lock, isNotNull);
    },
  );

  test('restarting archives the old game and starts a fresh dry run with the same settings', () async {
    final g = await start(dryRunDays: 0);
    await g.addProgress('read', 12);
    clock.set(DateTime(2026, 10, 19, 15));

    final fresh = (await g.restartTrial())!;
    expect(store.archived, hasLength(1));
    expect(store.archived.single.log.last.type, 'trial_restarted');
    expect(store.archived.single.progress.values.single['read'], 12);

    expect(fresh.trialDay, 1);
    expect(fresh.isDryRunToday, isTrue);
    expect(fresh.todaysTasks.single.id, 'read');
    expect(fresh.blockedToday, {insta});
    expect(fresh.todaysProgress, isEmpty);
  });

  test(
    'restart is refused while a penalty is in effect, so it cannot erase one',
    () async {
      final g = await start(dryRunDays: 0);
      clock.set(DateTime(2026, 10, 20, 8)); // Monday failed: 10 push-ups today
      await g.tick();
      expect(g.penaltyInEffect, isTrue);

      expect(await g.restartTrial(), isNull);
      expect(store.archived, isEmpty);
      expect(g.state.debt!.primaryOwed, 10);
    },
  );
}
