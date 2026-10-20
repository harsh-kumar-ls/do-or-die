import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/app/penalty_enforcer.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:do_or_die/platform/blocker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call so tests can check exactly what reached the phone.
class FakeBlocker extends NoopAppBlocker {
  final calls = <String>[];
  Set<String> packages = {};
  (DateTime, DateTime)? window;
  String? judgeDue;

  @override
  Future<void> setBlockedPackages(Set<String> p) async {
    calls.add('packages');
    packages = {...p};
  }

  @override
  Future<void> setLockWindow(DateTime s, DateTime e) async {
    calls.add('window');
    window = (s, e);
  }

  @override
  Future<void> clearLockWindow() async {
    calls.add('clear');
    window = null;
  }

  @override
  Future<void> setJudgeDueFrom(String day) async {
    calls.add('judge');
    judgeDue = day;
  }
}

const tasks = [
  TaskDefinition(id: 'read', name: 'Read', type: TaskType.counter, target: 30),
];
const insta = 'com.instagram.android';
const yt = 'com.google.android.youtube';

void main() {
  late FixedClock clock;
  late FakeBlocker blocker;
  late PenaltyEnforcer enforcer;

  setUp(() {
    clock = FixedClock(DateTime(2026, 10, 19, 10)); // Monday 10:00
    blocker = FakeBlocker();
    enforcer = PenaltyEnforcer(blocker, clock: clock);
  });

  Future<GameService> start() => GameService.start(
    store: MemoryGameStore(),
    tasks: tasks,
    blockedPackages: const {insta, yt},
    clock: clock,
    random: Random(5),
  );

  test(
    'pushes the chosen apps, no window, and today as the first unjudged day',
    () async {
      final g = await start();
      await enforcer.sync(g);
      expect(blocker.packages, {insta, yt});
      expect(blocker.window, isNull);
      expect(blocker.calls, contains('clear'));
      expect(blocker.judgeDue, '2026-10-19');
    },
  );

  test(
    'a failed day pushes the exact random window the engine scheduled',
    () async {
      final g = await start();
      clock.set(DateTime(2026, 10, 20, 6)); // Tuesday 06:00: Monday failed
      await g.tick();
      await enforcer.sync(g);

      final lock = g.state.lock!;
      expect(blocker.window, (lock.start, lock.end));
      expect(lock.end.difference(lock.start), const Duration(hours: 4));
      expect(blocker.judgeDue, '2026-10-20');
    },
  );

  test('nothing is re-sent when nothing changed', () async {
    final g = await start();
    await enforcer.sync(g);
    final before = blocker.calls.length;
    await enforcer.sync(g);
    await enforcer.sync(g);
    expect(blocker.calls.length, before);
  });

  test(
    'adding an app is pushed immediately; removing waits for tomorrow',
    () async {
      final g = await start();
      await enforcer.sync(g);

      await g.addBlockedApp('com.pubg.imobile');
      await enforcer.sync(g);
      expect(blocker.packages, contains('com.pubg.imobile'));

      await g.removeBlockedApp(yt);
      await enforcer.sync(g);
      expect(blocker.packages, contains(yt), reason: 'still locked today');

      clock.set(DateTime(2026, 10, 20, 9));
      await enforcer.sync(g);
      expect(blocker.packages, isNot(contains(yt)));
    },
  );

  test(
    'the emergency exit clears the window on the phone and is logged',
    () async {
      final g = await start();
      clock.set(DateTime(2026, 10, 20, 6));
      await g.tick();
      final lock = g.state.lock!;
      clock.set(lock.start.add(const Duration(minutes: 10)));
      await enforcer.sync(g);
      expect(blocker.window, isNotNull);

      expect(await g.emergencyStop(), isTrue);
      await enforcer.sync(g);
      expect(blocker.window, isNull);
      final entry = g.game.log.lastWhere((e) => e.type == 'emergency_stop');
      expect(entry.data['minutesRemaining'], 230);
      // Exercise owed is untouched.
      expect(g.state.debt!.pushupsOwed, 50);
    },
  );

  test('the emergency exit does nothing when no lock is running', () async {
    final g = await start();
    final logged = g.game.log.length;
    expect(await g.emergencyStop(), isFalse);
    expect(g.game.log.length, logged);
  });

  test('a lock that has already ended is cleared from the phone', () async {
    final g = await start();
    clock.set(DateTime(2026, 10, 20, 6));
    await g.tick();
    await enforcer.sync(g);
    expect(blocker.window, isNotNull);

    clock.set(g.state.lock!.end.add(const Duration(minutes: 1)));
    await enforcer.sync(g);
    expect(blocker.window, isNull);
  });
}
