import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:flutter_test/flutter_test.dart';

const tasks = [
  TaskDefinition(id: 'study', name: 'Study', type: TaskType.timer, target: 120),
  TaskDefinition(id: 'read', name: 'Read', type: TaskType.counter, target: 30),
];

void main() {
  late MemoryGameStore store;
  late FixedClock clock;

  setUp(() {
    store = MemoryGameStore();
    clock = FixedClock(DateTime(2026, 10, 19, 20, 0)); // Monday 20:00
  });

  Future<GameService> start() => GameService.start(
    store: store,
    tasks: tasks,
    blockedPackages: const {},
    clock: clock,
    random: Random(1),
  );

  test('a running timer shows live minutes and credits them on stop', () async {
    final g = await start();
    await g.startTimer('study');
    clock.advance(const Duration(minutes: 45, seconds: 30));
    expect(g.isTimerRunning('study'), isTrue);
    expect(g.liveProgress('study'), 45 * 60 + 30);
    expect(g.runningSeconds('study'), 45 * 60 + 30);

    await g.stopTimer();
    expect(g.isTimerRunning('study'), isFalse);
    expect(g.todaysProgress['study'], 45 * 60 + 30);
  });

  test('a running timer survives the app being restarted', () async {
    final g = await start();
    await g.startTimer('study');
    clock.advance(const Duration(minutes: 30));
    final again = (await GameService.load(
      store: store,
      clock: clock,
      random: Random(1),
    ))!;
    expect(again.isTimerRunning('study'), isTrue);
    expect(again.liveProgress('study'), 30 * 60);
  });

  test(
    'a timer left running past midnight only counts until midnight',
    () async {
      final g = await start();
      clock.set(DateTime(2026, 10, 19, 22, 30));
      await g.startTimer('study');
      clock.set(DateTime(2026, 10, 20, 1, 0)); // Tuesday 01:00
      await g.tick();

      expect(g.isTimerRunning('study'), isFalse);
      expect(g.game.progress[const DayKey(2026, 10, 19)]!['study'], 90 * 60);
      // 90 of 120 minutes: Monday still fails.
      expect(g.game.log.any((e) => e.type == 'quest_failed'), isTrue);
      final stopped = g.game.log.lastWhere((e) => e.type == 'timer_stopped');
      expect(stopped.data['seconds'], 90 * 60);
    },
  );

  test('timer minutes past midnight can complete the day if enough', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 19, 21, 0));
    await g.addProgress('read', 30);
    await g.startTimer('study');
    clock.set(DateTime(2026, 10, 20, 0, 30));
    await g.tick();
    expect(g.game.progress[const DayKey(2026, 10, 19)]!['study'], 180 * 60);
    expect(g.game.log.any((e) => e.type == 'quest_cleared'), isTrue);
  });

  test('only timer tasks can be timed', () async {
    final g = await start();
    await g.startTimer('read');
    expect(g.isTimerRunning('read'), isFalse);
  });
}
