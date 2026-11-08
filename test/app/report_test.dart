import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/app/report.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/system_catalogue.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:do_or_die/domain/penalty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixedClock clock;
  final day1 = DayKey(2026, 10, 19);

  setUp(() => clock = FixedClock(day1.at(9 * 60)));

  Future<GameService> awaken({int dryRunDays = 0}) => GameService.awaken(
    store: MemoryGameStore(),
    system: SystemKind.fitness,
    placement: Rank.e,
    blockedPackages: const {'com.instagram.android'},
    dryRunDays: dryRunDays,
    clock: clock,
    random: Random(2),
  );

  Future<void> day(GameService g, {required bool clear}) async {
    if (clear) {
      for (final t in g.todaysTasks) {
        await g.setProgress(t.id, t.goal);
      }
    }
    clock.set(g.today.addDays(1).at(9 * 60));
    await g.tick();
  }

  TrialReport report(GameService g) =>
      TrialReport.from(g.game, g.today, systemCatalogue);

  test('counts cleared and failed days and the streaks', () async {
    final g = await awaken();
    for (final clear in [true, true, false, true, true, true]) {
      await day(g, clear: clear);
    }
    final r = report(g);
    expect(r.days, 6);
    expect(r.cleared, 5);
    expect(r.failed, 1);
    expect(r.longestStreak, 3);
    expect(r.currentStreak, 3);
    expect(r.clearRate, 83);
    expect(r.penaltyZones, 1);
  });

  test('dry-run days are marked, and never counted as failures', () async {
    final g = await awaken(dryRunDays: 2);
    await day(g, clear: false);
    await day(g, clear: false);
    await day(g, clear: true);
    final r = report(g);
    expect(r.calendar.map((c) => c.$2), [
      DayMark.dryRun,
      DayMark.dryRun,
      DayMark.cleared,
    ]);
    expect(r.failed, 0);
    expect(r.penaltyZones, 0);
  });

  test('covers at most the last 30 judged days', () async {
    final g = await awaken();
    for (var i = 0; i < 35; i++) {
      await day(g, clear: true);
    }
    expect(report(g).days, 30);
  });

  test('rank journey and then-and-now after a Dungeon', () async {
    final g = await awaken();
    for (var i = 0; i < 21; i++) {
      await day(g, clear: true);
    }
    expect(await g.enterGate(), isTrue);
    for (var i = 0; i < 4; i++) {
      await day(g, clear: true); // today, floors 1-3
    }
    final r = report(g);
    expect(r.startRank, Rank.e);
    expect(r.rank, Rank.d);
    expect(r.dungeonsCleared, 1);
    expect(r.gatesOpened, 1);
    final pushups = r.targets.firstWhere((t) => t.label == 'Push-ups');
    expect((pushups.before, pushups.after), (10, 20));
  });

  test('releases are counted in the honesty section and the verdict', () async {
    final g = await awaken();
    await day(g, clear: false);
    final lock = g.state.lock!;
    clock.set(lock.start.add(const Duration(minutes: 1)));
    expect(await g.releaseLock(), isTrue);
    clock.set(g.today.addDays(1).at(9 * 60));
    await g.tick();
    final r = report(g);
    expect(r.releases, 1);
    expect(r.verdict, contains('1 release taken. They were counted.'));
  });

  test('a report is due once on day 31', () async {
    final g = await awaken();
    for (var i = 0; i < 29; i++) {
      await day(g, clear: true);
    }
    expect(g.trialDay, 30);
    expect(g.reportDue, isFalse);
    await day(g, clear: true);
    expect(g.reportDue, isTrue);
    await g.markReportIssued();
    expect(g.reportDue, isFalse);
  });

  test(
    'every change that can soften the game is counted in the report',
    () async {
      final g = await awaken();
      await g.setLockStart(20 * 60);
      await g.setSleepWindow(
        const SleepWindow(startMinute: 22 * 60, endMinute: 6 * 60),
      );
      await g.setReduction(10);
      final r = TrialReport.from(g.game, g.today, systemCatalogue);
      expect(r.ruleChanges, 3);
    },
  );
}
