import 'dart:convert';
import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/penalty.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:flutter_test/flutter_test.dart';

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
const blocked = {
  'com.instagram.android',
  'com.google.android.youtube',
  'com.pubg.imobile',
};

void main() {
  late MemoryGameStore store;
  late FixedClock clock;

  // Monday 19 Oct 2026, 10:00.
  DateTime mondayAt(int hour) => DateTime(2026, 10, 19, hour);

  setUp(() {
    store = MemoryGameStore();
    clock = FixedClock(mondayAt(10));
  });

  Future<GameService> startGame() => GameService.start(
    store: store,
    tasks: tasks,
    blockedPackages: blocked,
    clock: clock,
    random: Random(3),
  );

  Future<GameService> reload() async =>
      (await GameService.load(store: store, clock: clock, random: Random(3)))!;

  Future<void> completeAll(GameService g) async {
    await g.setProgress('breakfast', 1);
    await g.addProgress('study', 7200);
    await g.addProgress('read', 30);
  }

  test('no saved game means load returns null', () async {
    expect(await GameService.load(store: store, clock: clock), isNull);
  });

  test('starting a game saves it and logs the start', () async {
    await startGame();
    final g = await reload();
    expect(g.todaysTasks.map((t) => t.id), ['breakfast', 'study', 'read']);
    expect(g.blockedToday, blocked);
    expect(g.game.log.single.type, 'game_started');
  });

  test('progress survives a restart', () async {
    final g = await startGame();
    await g.addProgress('study', 45);
    await g.addProgress('study', 30);
    final again = await reload();
    expect(again.todaysProgress['study'], 75);
  });

  test('a failed day, restored from storage, becomes a penalty and lock the next day', () async {
    final g = await startGame();
    await g.setProgress('breakfast', 1);
    clock.set(DateTime(2026, 10, 20, 6)); // Tuesday 06:00
    final again = await reload();

    final debt = again.state.debt!;
    expect(debt.pushupsOwed, 50);
    expect(debt.dueDay, const DayKey(2026, 10, 20));
    expect(again.state.lock!.day, const DayKey(2026, 10, 20));
    final types = again.game.log.map((e) => e.type).toList();
    expect(
      types,
      containsAllInOrder(['quest_failed', 'penalty_issued', 'lock_scheduled']),
    );
  });

  test('a cleared day gives XP after restart', () async {
    final g = await startGame();
    await completeAll(g);
    clock.set(DateTime(2026, 10, 20, 8));
    final again = await reload();
    expect(again.state.xp, 100);
    expect(again.state.debt, isNull);
  });

  test('exercise is logged with what remains', () async {
    final g = await startGame();
    clock.set(DateTime(2026, 10, 20, 9)); // Monday failed
    await g.tick();
    await g.recordExercise(pushups: 40);
    final entry = g.game.log.lastWhere((e) => e.type == 'exercise');
    expect(entry.data['pushups'], 40);
    expect(entry.data['pushupsRemaining'], 10);
  });

  test('exercise with no debt due does nothing and logs nothing', () async {
    final g = await startGame();
    final before = g.game.log.length;
    await g.recordExercise(pushups: 10);
    expect(g.game.log.length, before);
  });

  test('progress for an unknown task is ignored', () async {
    final g = await startGame();
    await g.setProgress('nope', 5);
    expect(g.todaysProgress, isEmpty);
  });

  test('plan edits apply tomorrow and are logged', () async {
    final g = await startGame();
    await g.editPlan([tasks[0]]);
    expect(g.todaysTasks, hasLength(3));
    clock.set(DateTime(2026, 10, 20, 9));
    expect(g.todaysTasks, hasLength(1));
    expect(g.game.log.any((e) => e.type == 'plan_edited'), isTrue);
  });

  test('removing a blocked app applies tomorrow; adding applies now', () async {
    final g = await startGame();
    await g.removeBlockedApp('com.pubg.imobile');
    await g.addBlockedApp('com.twitter.android');
    expect(g.blockedToday, contains('com.pubg.imobile'));
    expect(g.blockedToday, contains('com.twitter.android'));
    clock.set(DateTime(2026, 10, 20, 9));
    expect(g.blockedToday, isNot(contains('com.pubg.imobile')));
  });

  test('settings, stats and emergency stops survive a restart', () async {
    final g = await startGame();
    await g.setSleepWindow(
      const SleepWindow(startMinute: 60, endMinute: 9 * 60),
    );
    await g.recordEmergencyStop();
    final again = await reload();
    expect(again.game.sleep.startMinute, 60);
    expect(
      again.game.log.where((e) => e.type == 'emergency_stop'),
      hasLength(1),
    );
  });

  test('stat allocation spends points and is logged', () async {
    final g = await startGame();
    for (var d = 0; d < 3; d++) {
      await completeAll(g);
      clock.advance(const Duration(days: 1));
      await g.tick();
    }
    expect(g.state.level, 2);
    await g.allocateStat(Stat.intellect);
    expect(g.state.stats[Stat.intellect], 1);
    expect(g.state.unspentStatPoints, 2);
    expect(g.game.log.where((e) => e.type == 'level_up'), hasLength(1));
  });

  test('the log only grows: every earlier entry is kept unchanged', () async {
    final g = await startGame();
    final snapshots = <List<String>>[];
    String key(e) => jsonEncode(e.toJson());

    await g.addProgress('study', 10);
    snapshots.add(g.game.log.map(key).toList());
    clock.set(DateTime(2026, 10, 21, 9));
    await g.tick();
    snapshots.add(g.game.log.map(key).toList());
    await g.recordEmergencyStop();
    snapshots.add(g.game.log.map(key).toList());

    for (var i = 1; i < snapshots.length; i++) {
      expect(snapshots[i].length, greaterThan(snapshots[i - 1].length));
      expect(
        snapshots[i].sublist(0, snapshots[i - 1].length),
        snapshots[i - 1],
      );
    }
    expect(() => g.game.log.clear(), throwsUnsupportedError);
  });

  test('export contains every log entry in JSON and CSV', () async {
    final g = await startGame();
    await g.addProgress('read', 12);
    await g.recordEmergencyStop();
    final json = jsonDecode(g.exportLogJson()) as List;
    expect(json, hasLength(g.game.log.length));
    final csv = g.exportLogCsv().split('\n');
    expect(csv.first, 'at,type,data');
    expect(csv, hasLength(g.game.log.length + 1));
  });

  test('every change is written to storage before it is visible', () async {
    final g = await startGame();
    final saves = store.saves;
    await g.addProgress('read', 5);
    expect(store.saves, saves + 1);
  });

  test(
    'moving the clock backwards after closing days changes nothing',
    () async {
      final g = await startGame();
      clock.set(DateTime(2026, 10, 21, 9));
      await g.tick();
      final log = g.game.log.length;
      clock.set(mondayAt(12));
      expect(await g.tick(), isEmpty);
      expect(g.game.log.length, log);
      // Monday is closed, so progress can't be added to it any more.
      await g.setProgress('breakfast', 1);
      expect(g.game.progress[const DayKey(2026, 10, 19)]?['breakfast'], isNull);
    },
  );
}
