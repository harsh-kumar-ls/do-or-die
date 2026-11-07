import 'dart:async';
import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:do_or_die/platform/usage_meter.dart';
import 'package:flutter_test/flutter_test.dart';

/// A usage meter whose answer can be held back, to overlap other calls with
/// a measurement in flight (as the 30-second poll does on a real phone).
class GatedMeter implements UsageMeter {
  int? minutes = 10;
  Completer<void>? gate;

  @override
  Future<int?> minutesUsed(Set<String> p, DateTime from, DateTime to) async {
    final g = gate;
    if (g != null) await g.future;
    return minutes;
  }
}

/// Every change must be applied on top of the one before it: two calls that
/// overlap must never drop either one's write. A dropped objective can turn
/// a cleared day into a wrongful penalty.
void main() {
  final day1 = DayKey(2026, 10, 19);
  late FixedClock clock;
  late GatedMeter meter;
  late MemoryGameStore store;

  setUp(() {
    clock = FixedClock(day1.at(9 * 60));
    meter = GatedMeter();
    store = MemoryGameStore();
  });

  Future<GameService> focusC() async {
    final g = await GameService.awaken(
      store: store,
      system: SystemKind.focus,
      placement: Rank.c, // social-media cap + "No phone at meals" checkbox
      blockedPackages: const {'com.instagram.android'},
      dryRunDays: 0,
      clock: clock,
      random: Random(1),
      meter: meter,
    );
    clock.set(day1.addDays(1).at(13 * 60));
    await g.tick();
    return g;
  }

  test(
    'an objective confirmed while screen time is being measured is kept',
    () async {
      final g = await focusC();
      final meals = g.todaysTasks.firstWhere((t) => !t.isCap);

      meter.gate = Completer<void>();
      final measuring = g.measureCaps();
      await Future<void>.delayed(Duration.zero);
      final tap = g.setProgress(meals.id, 1);
      await Future<void>.delayed(Duration.zero);
      meter.gate!.complete();
      await Future.wait([measuring, tap]);

      expect(g.todaysProgress[meals.id], 1);
      expect(g.todaysProgress['social'], 10);
      // And it survives a reload.
      final saved = await store.load();
      expect(saved!.progress[g.today]![meals.id], 1);
    },
  );

  test('two overlapping checks judge a day exactly once', () async {
    final g = await focusC();
    clock.set(day1.addDays(2).at(9 * 60)); // day 2 now needs judging
    meter.gate = Completer<void>();
    final a = g.tick();
    final b = g.tick();
    await Future<void>.delayed(Duration.zero);
    meter.gate!.complete();
    await Future.wait([a, b]);

    final judged = g.game.log
        .where((e) => e.type == 'quest_failed' || e.type == 'quest_cleared')
        .where((e) => e.data['day'] == day1.addDays(1).toString());
    expect(judged, hasLength(1));
  });

  test('a penalty paid during a day-close is not lost', () async {
    final g = await GameService.awaken(
      store: store,
      system: SystemKind.fitness,
      placement: Rank.e,
      blockedPackages: const {'com.instagram.android'},
      dryRunDays: 0,
      clock: clock,
      random: Random(1),
      meter: meter,
    );
    clock.set(day1.addDays(1).at(9 * 60));
    await g.tick(); // day 1 failed: 10 push-ups and 15 squats owed today
    final a = g.recordPenalty(primary: 4);
    final b = g.recordPenalty(primary: 3);
    await Future.wait([a, b]);
    expect(g.state.debt!.primaryDone, 7);
  });
}
