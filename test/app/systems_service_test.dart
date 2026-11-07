import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/app/penalty_enforcer.dart';
import 'package:do_or_die/data/codec.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/dungeon.dart';
import 'package:do_or_die/domain/engine.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/penalty_kind.dart';
import 'package:do_or_die/domain/system_catalogue.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:do_or_die/platform/blocker.dart';
import 'package:do_or_die/platform/usage_meter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'penalty_enforcer_test.dart' show FakeBlocker;

/// Screen time the test decides; null means no usage access.
class FakeMeter implements UsageMeter {
  int? minutes;

  @override
  Future<int?> minutesUsed(Set<String> p, DateTime from, DateTime to) async =>
      minutes;
}

const blocked = {'com.instagram.android'};

void main() {
  late MemoryGameStore store;
  late FixedClock clock;
  late FakeMeter meter;

  // Monday 19 Oct 2026.
  final day1 = DayKey(2026, 10, 19);

  setUp(() {
    store = MemoryGameStore();
    clock = FixedClock(day1.at(9 * 60));
    meter = FakeMeter();
  });

  Future<GameService> awaken(
    SystemKind kind, {
    Rank placement = Rank.e,
    int dryRunDays = 0,
  }) => GameService.awaken(
    store: store,
    system: kind,
    placement: placement,
    blockedPackages: blocked,
    dryRunDays: dryRunDays,
    clock: clock,
    random: Random(3),
    meter: meter,
  );

  /// Completes every non-cap item of today's quest.
  Future<void> clearToday(GameService g) async {
    for (final t in g.todaysTasks) {
      if (t.isCap) continue;
      await g.setProgress(t.id, t.goal);
    }
  }

  /// Moves to 09:00 on the next day and judges.
  Future<List<GameEvent>> nextDay(GameService g) {
    clock.set(DayKey.fromDateTime(clock.now()).addDays(1).at(9 * 60));
    return g.tick();
  }

  /// Clears [n] days in a row, ending at 09:00 on the day after the last.
  Future<void> clearDays(GameService g, int n) async {
    for (var i = 0; i < n; i++) {
      await clearToday(g);
      await nextDay(g);
    }
  }

  group('awakening', () {
    test('the System writes the quest: Fitness E daily quest today', () async {
      final g = await awaken(SystemKind.fitness);
      expect(g.todaysTasks.map((t) => t.id), ['walk', 'pushups', 'squats']);
      expect(g.todaysTasks.first.type, TaskType.timer);
      expect(g.game.log.single.type, 'awakened');
      expect(g.game.log.single.data['system'], 'fitness');
    });

    test('the System survives a save and reload', () async {
      await awaken(SystemKind.personality, placement: Rank.d);
      final loaded = await GameService.load(store: store, clock: clock);
      expect(loaded!.systems!.active, SystemKind.personality);
      expect(loaded.systems!.rank, Rank.d);
      expect(loaded.todaysTasks.map((t) => t.id), contains('greet'));
    });

    test('placement above C is refused', () async {
      expect(
        () => awaken(SystemKind.fitness, placement: Rank.b),
        throwsArgumentError,
      );
    });
  });

  group('Gate', () {
    test(
      'opens at day close when 21 of the last 30 days are cleared',
      () async {
        final g = await awaken(SystemKind.fitness);
        await clearDays(g, 20);
        expect(g.systems!.gate, isNull);
        await clearToday(g);
        await nextDay(g);
        expect(g.systems!.gate, isNotNull);
        final events = g.takeSystemEvents();
        expect(events.whereType<GateOpened>(), hasLength(1));
        expect(g.game.log.map((e) => e.type), contains('gate_opened'));
      },
    );

    test('dry-run days never count toward a Gate', () async {
      final g = await awaken(SystemKind.fitness, dryRunDays: 3);
      await clearDays(g, 21);
      expect(g.systems!.gate, isNull);
      await clearDays(g, 3);
      expect(g.systems!.gate, isNotNull);
    });

    test('an unentered Gate closes after 48 hours, without penalty', () async {
      final g = await awaken(SystemKind.fitness);
      await clearDays(g, 21);
      // Opened at 09:00; two cleared days later it is 09:00, 48 h on.
      await clearDays(g, 2);
      expect(g.systems!.gate, isNull);
      expect(g.state.debt, isNull);
      expect(g.game.log.map((e) => e.type), contains('gate_expired'));
    });
  });

  group('Dungeon', () {
    Future<GameService> atGate() async {
      final g = await awaken(SystemKind.fitness);
      await clearDays(g, 21);
      expect(await g.enterGate(), isTrue);
      return g;
    }

    test('Floor 1 is the next day: the daily quest +25%', () async {
      final g = await atGate();
      // Today is still the normal daily quest.
      expect(g.todaysTasks.firstWhere((t) => t.id == 'pushups').target, 10);
      await clearToday(g);
      await nextDay(g);
      final floor1 = {for (final t in g.todaysTasks) t.id: t.target};
      expect(floor1, {'walk': 15, 'pushups': 13, 'squats': 19});
    });

    test('Floor 2 (+50%) refuses progress after 18:00', () async {
      final g = await atGate();
      await clearDays(g, 2); // today, then floor 1
      expect(g.systems!.floorOn(g.today), 2);
      final pushups = g.todaysTasks.firstWhere((t) => t.id == 'pushups');
      expect(pushups.target, 15);
      clock.set(g.today.at(18 * 60 + 1));
      await g.setProgress('pushups', 15);
      expect(g.liveProgress('pushups'), 0);
      expect(g.pastDeadline, isTrue);
    });

    test(
      'a timer running at the Floor 2 deadline counts only to 18:00',
      () async {
        final g = await atGate();
        await clearDays(g, 2);
        clock.set(g.today.at(17 * 60 + 50));
        await g.startTimer('walk');
        clock.set(g.today.at(18 * 60 + 30));
        expect(g.liveProgress('walk'), 600);
        await g.tick();
        expect(g.game.timer, isNull);
        expect(g.todaysProgress['walk'], 600);
      },
    );

    test(
      'clearing all three floors ranks up, +5 stat points, a title',
      () async {
        final g = await atGate();
        await clearDays(g, 3); // today, floor 1, floor 2
        expect(g.systems!.floorOn(g.today), 3);
        expect(g.todaysTasks.map((t) => t.id), ['squats_unbroken', 'walk_15']);
        final pointsBefore = g.state.unspentStatPoints;
        final levelsBefore = g.state.level;
        await clearToday(g);
        await nextDay(g);
        expect(g.systems!.rank, Rank.d);
        final levelPoints = (g.state.level - levelsBefore) * 3;
        expect(
          g.state.unspentStatPoints - pointsBefore - levelPoints,
          DungeonRules.clearStatPoints,
        );
        expect(g.systems!.titles, ['Gatebreaker · Fitness D']);
        // Next day: the D daily quest.
        expect(g.todaysTasks.map((t) => t.id), contains('plank'));
        expect(g.takeSystemEvents().whereType<DungeonCleared>(), hasLength(1));
      },
    );

    test('failing a floor: Dungeon Penalty next day, double lock, exercise '
        'never above the daily quest', () async {
      final g = await atGate();
      await clearToday(g);
      await nextDay(g); // floor 1 today
      final level = g.state.level;
      final p = g.engine.penalties;
      await nextDay(g); // floor 1 not cleared
      final debt = g.state.debt!;
      // Rank E daily quest: 10 push-ups and 15 squats. Never doubled.
      expect((debt.primaryOwed, debt.secondaryOwed), (10, 15));
      final lock = g.state.lock!;
      expect(
        lock.end.difference(lock.start).inMinutes,
        lessThanOrEqualTo(p.lockMinutesForLevel(level) * 2),
      );
      expect(g.systems!.dungeon, isNull);
      expect(g.systems!.dungeonPenaltyDay, g.today);
      expect(g.dungeonPenaltyToday, isTrue);
      expect(g.systems!.rank, Rank.e, reason: 'no rank loss');
      expect(g.takeSystemEvents().whereType<DungeonFailed>(), hasLength(1));
    });

    test('the Dungeon Penalty reaches the phone in its own mode', () async {
      final g = await atGate();
      await clearToday(g);
      await nextDay(g);
      await nextDay(g); // floor 1 failed
      final blocker = FakeBlocker();
      await PenaltyEnforcer(blocker, clock: clock).sync(g);
      expect(blocker.mode, LockMode.dungeon);
    });

    test('a normal failed day keeps the normal penalty and mode', () async {
      final g = await awaken(SystemKind.fitness);
      await nextDay(g);
      expect(
        (g.state.debt!.primaryOwed, g.state.debt!.secondaryOwed),
        (10, 15),
      );
      final blocker = FakeBlocker();
      await PenaltyEnforcer(blocker, clock: clock).sync(g);
      expect(blocker.mode, LockMode.penalty);
    });

    test('restart is refused during a Dungeon', () async {
      final g = await atGate();
      await clearToday(g);
      await nextDay(g);
      expect(await g.abandon(), isFalse);
      expect(store.archived, isEmpty);
    });
  });

  group('reduction valve', () {
    test('applies from tomorrow and halves that day\'s XP', () async {
      final g = await awaken(SystemKind.fitness);
      await g.setReduction(20);
      expect(g.reductionToday, 0);
      expect(g.reductionTomorrow, 20);
      await clearToday(g);
      final full = await nextDay(g);
      expect(
        full.whereType<QuestCleared>().single.xpGained,
        g.engine.config.xpPerClear,
      );
      expect(g.todaysTasks.firstWhere((t) => t.id == 'pushups').target, 8);
      await clearToday(g);
      final reduced = await nextDay(g);
      expect(
        reduced.whereType<QuestCleared>().single.xpGained,
        g.engine.config.xpPerClear ~/ 2,
      );
      expect(g.game.log.map((e) => e.type), contains('reduction_set'));
    });

    test('is capped at 20%', () async {
      final g = await awaken(SystemKind.fitness);
      await g.setReduction(50);
      expect(g.reductionTomorrow, 20);
    });
  });

  group('screen-time caps', () {
    // Focus D: social media under 60 minutes.
    test('measured under the cap: cleared', () async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      meter.minutes = 45;
      final events = await nextDay(g);
      expect(events.whereType<QuestCleared>(), hasLength(1));
      expect(g.game.log.map((e) => e.type), contains('cap_measured'));
    });

    test('measured over the cap: failed', () async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      meter.minutes = 61;
      final events = await nextDay(g);
      expect(events.whereType<QuestFailed>(), hasLength(1));
    });

    test('progress cannot be typed in for a cap', () async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      await g.setProgress('social', 0);
      expect(g.liveProgress('social'), isNull);
    });

    test('without usage access, an unconfirmed cap is not kept', () async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      final events = await nextDay(g);
      expect(events.whereType<QuestFailed>(), hasLength(1));
    });

    test('without usage access, the honour confirmation clears it', () async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      expect(await g.confirmCap('social'), isTrue);
      final events = await nextDay(g);
      expect(events.whereType<QuestCleared>(), hasLength(1));
      expect(g.game.log.where((e) => e.data['honour'] == true), hasLength(1));
    });

    test('honour confirmation is refused when it can be measured', () async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      meter.minutes = 10;
      expect(await g.confirmCap('social'), isFalse);
    });
  });

  group('phone-free blocks', () {
    // Focus E: no phone for 20 minutes after waking.
    test('only the longest single block counts', () async {
      final g = await awaken(SystemKind.focus);
      final t = g.todaysTasks.single;
      expect(t.type, TaskType.phoneFree);
      await g.startTimer(t.id);
      expect(g.focusBlock, isNotNull);
      clock.advance(const Duration(minutes: 10));
      await g.stopTimer();
      expect(g.focusBlock, isNull);
      await g.startTimer(t.id);
      clock.advance(const Duration(minutes: 15));
      await g.stopTimer();
      expect(g.liveProgress(t.id), 15 * 60);
      expect(t.isComplete(g.liveProgress(t.id)), isFalse);
      await g.startTimer(t.id);
      clock.advance(const Duration(minutes: 20));
      expect(t.isComplete(g.liveProgress(t.id)), isTrue);
    });

    test('a running block locks the chosen apps on the phone', () async {
      final g = await awaken(SystemKind.focus);
      final blocker = FakeBlocker();
      final enforcer = PenaltyEnforcer(blocker, clock: clock);
      await g.startTimer(g.todaysTasks.single.id);
      await enforcer.sync(g);
      expect(blocker.focus, isNotNull);
      await g.stopTimer();
      await enforcer.sync(g);
      expect(blocker.focus, isNull);
    });
  });

  group('restart', () {
    test('archives the game and clears it for a new Awakening', () async {
      final g = await awaken(SystemKind.fitness);
      expect(await g.abandon(), isTrue);
      expect(store.archived, hasLength(1));
      expect(await store.load(), isNull);
    });

    test('is refused while a penalty is in effect', () async {
      final g = await awaken(SystemKind.fitness);
      await nextDay(g);
      expect(await g.abandon(), isFalse);
    });
  });

  group('migration', () {
    test('an older game with its own objectives needs migrating', () async {
      final g = await GameService.start(
        store: store,
        tasks: const [
          TaskDefinition(
            id: 'a',
            name: 'A',
            type: TaskType.checkbox,
            target: 1,
          ),
        ],
        blockedPackages: blocked,
        clock: clock,
      );
      expect(g.needsMigration, isTrue);
      await nextDay(g); // failed: a penalty is in effect today
      expect(g.needsMigration, isFalse);
    });
  });

  group('choosing the next System', () {
    test('is refused until the current one is complete', () async {
      final g = await awaken(SystemKind.fitness);
      expect(await g.chooseSystem(SystemKind.focus, Rank.e), isFalse);
      expect(g.systems!.active, SystemKind.fitness);
    });
  });

  group('QA regressions', () {
    test('a System chosen late in the day starts tomorrow: no wrongful '
        'penalty tonight', () async {
      // Complete Fitness through a hand-built state: S held for 30 days.
      final g = await awaken(SystemKind.fitness);
      final sys = g.systems!;
      final done = sys.copyWith(
        progress: SystemProgress(
          active: SystemKind.fitness,
          ranks: const {SystemKind.fitness: Rank.s},
          completed: const {SystemKind.fitness},
        ),
      );
      await store.save(g.game.copyWith(systems: done));
      final h = (await GameService.load(
        store: store,
        clock: clock,
        meter: meter,
      ))!;
      expect(h.todaysTasks, isEmpty);
      clock.set(h.today.at(23 * 60 + 50));
      expect(await h.chooseSystem(SystemKind.personality, Rank.e), isTrue);
      expect(h.todaysTasks, isEmpty, reason: 'starts tomorrow');
      final events = await nextDay(h);
      expect(events.whereType<QuestFailed>(), isEmpty);
      expect(h.state.debt, isNull);
      expect(h.todaysTasks.map((t) => t.id), contains('pages'));
    });

    Future<GameService> focusFloor2() async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      meter.minutes = 10;
      for (var i = 0; i < 21; i++) {
        await nextDay(g);
      }
      expect(await g.enterGate(), isTrue);
      await nextDay(g); // floor 1 today
      await nextDay(g); // floor 2 today
      expect(g.systems!.floorOn(g.today), 2);
      return g;
    }

    test('Floor 2 caps are measured only up to 18:00', () async {
      final g = await focusFloor2();
      final floorDay = g.today;
      final seen = <DateTime>[];
      final spy = _SpyMeter(seen, 20);
      final h = (await GameService.load(
        store: store,
        clock: clock,
        meter: spy,
      ))!;
      clock.set(h.today.addDays(1).at(9 * 60));
      await h.tick();
      expect(seen.last, floorDay.at(18 * 60));
    });

    test(
      'a partial reading never stands when judging has no reading',
      () async {
        final g = await awaken(SystemKind.focus, placement: Rank.d);
        meter.minutes = 5;
        await g.measureCaps(); // 09:00 reading: 5 minutes
        meter.minutes = null; // usage access revoked before midnight
        final events = await nextDay(g);
        expect(events.whereType<QuestFailed>(), hasLength(1));
      },
    );

    test('a reading over the cap cannot be confirmed away', () async {
      final g = await awaken(SystemKind.focus, placement: Rank.d);
      meter.minutes = 90;
      await g.measureCaps();
      meter.minutes = null;
      expect(await g.confirmCap('social'), isFalse);
    });

    test("the Fitness penalty follows the rank's own daily quest", () async {
      final g = await awaken(SystemKind.fitness, placement: Rank.d);
      await nextDay(g);
      // Rank D daily quest: 20 push-ups and 30 squats.
      expect(
        (g.state.debt!.primaryOwed, g.state.debt!.secondaryOwed),
        (20, 30),
      );
    });

    test(
      'the reduction valve lowers the Fitness penalty with the quest',
      () async {
        final g = await awaken(SystemKind.fitness, placement: Rank.d);
        await g.setReduction(20);
        await nextDay(g); // day 1 failed at full quest
        await nextDay(g); // day 2 failed at -20%
        expect(
          (g.state.debt!.primaryOwed, g.state.debt!.secondaryOwed),
          (16, 24),
        );
      },
    );

    test('rank S Fitness has no push-ups in its quest, so it owes none', () {
      final quest = fitnessSystem.at(Rank.s).daily;
      expect(exerciseVolume(quest), (0, 0));
    });

    test(
      'with the clock set back, floor 1 never lands on a judged day',
      () async {
        final g = await awaken(SystemKind.fitness);
        await clearDays(g, 21);
        final firstOpen = g.state.nextDayToClose;
        clock.set(firstOpen.addDays(-4).at(12 * 60));
        // The Gate was opened "in the future" now; move to its window.
        final gate = g.systems!.gate!;
        clock.set(gate.openedAt.subtract(const Duration(days: 4)));
        final sys = g.systems!.enter(
          gate.openedAt
              .add(const Duration(hours: 1))
              .subtract(const Duration(days: 4)),
          firstOpenDay: firstOpen,
        );
        expect(sys, isNotNull);
        expect(sys!.$1.dungeon!.firstFloor, firstOpen.addDays(1));
      },
    );

    test('floors ignore the reduction valve and earn full XP', () async {
      final g = await awaken(SystemKind.fitness);
      await clearDays(g, 21);
      await g.enterGate();
      await g.setReduction(20);
      await clearToday(g);
      await nextDay(g); // floor 1
      expect(g.todaysTasks.firstWhere((t) => t.id == 'pushups').target, 13);
      await clearToday(g);
      final events = await nextDay(g);
      expect(
        events.whereType<QuestCleared>().single.xpGained,
        g.engine.config.xpPerClear,
      );
    });

    test('a running phone-free block on Floor 2 unlocks at 18:00', () async {
      final g = await awaken(SystemKind.focus);
      // Focus B, on Floor 2 today.
      final sys = g.systems!.copyWith(
        progress: const SystemProgress(
          active: SystemKind.focus,
          ranks: {SystemKind.focus: Rank.b},
        ),
        dungeon: () => Dungeon(Rank.b, g.today.addDays(-1)),
      );
      await store.save(g.game.copyWith(systems: sys));
      final f = (await GameService.load(
        store: store,
        clock: clock,
        meter: meter,
      ))!;
      expect(f.systems!.floorOn(f.today), 2);
      clock.set(f.today.at(17 * 60));
      final block = f.todaysTasks.firstWhere(
        (t) => t.type == TaskType.phoneFree,
      );
      await f.startTimer(block.id);
      final blocker = FakeBlocker();
      await PenaltyEnforcer(blocker, clock: clock).sync(f);
      expect(blocker.focus!.$2, f.today.at(18 * 60));
    });

    test('a report missed on day 31 is still issued later', () async {
      final g = await awaken(SystemKind.fitness);
      await clearDays(g, 32);
      expect(g.trialDay, 33);
      expect(g.reportDue, isTrue);
      await g.markReportIssued();
      expect(g.reportDue, isFalse);
    });
  });

  group('penalties follow the System', () {
    test('Fitness owes push-ups and squats from its own daily quest', () async {
      final g = await awaken(SystemKind.fitness);
      await nextDay(g);
      expect(g.state.debt!.kind, PenaltyKind.exercise);
      expect(
        (g.state.debt!.primaryOwed, g.state.debt!.secondaryOwed),
        (10, 15),
      );
    });

    test(
      'Personality owes pages and a written reflection, never push-ups',
      () async {
        final g = await awaken(SystemKind.personality);
        await nextDay(g);
        final debt = g.state.debt!;
        expect(debt.kind, PenaltyKind.reading);
        expect((debt.primaryOwed, debt.secondaryOwed), (20, 1));
        expect(await g.submitReflection('too short'), isFalse);
        // Five lines of one word each don't count.
        expect(await g.submitReflection('a\nb\nc\nd\ne'), isFalse);
        await g.recordPenalty(secondary: 1); // can't be ticked off
        expect(g.state.debt!.secondaryDone, 0);
        expect(
          await g.submitReflection(
            'I skipped my reading today.\nI was tired after work.\n'
            'I left it far too late.\nTomorrow I read at lunch.\n'
            'The phone stays in another room.',
          ),
          isTrue,
        );
        await g.recordPenalty(primary: 20);
        expect(g.state.debt!.isPaid, isTrue);
        expect(g.game.log.where((e) => e.type == 'reflection'), hasLength(1));
      },
    );

    test('Focus owes a phone-free block, paid only by running it', () async {
      final g = await awaken(SystemKind.focus);
      await nextDay(g);
      final debt = g.state.debt!;
      expect(debt.kind, PenaltyKind.focus);
      expect((debt.primaryOwed, debt.secondaryOwed), (60, 0));
      await g.recordPenalty(primary: 60); // can't be typed in
      expect(g.state.debt!.primaryDone, 0);
      await g.startPenaltyBlock();
      expect(g.focusBlock, isNotNull, reason: 'apps lock during the block');
      final blocker = FakeBlocker();
      await PenaltyEnforcer(blocker, clock: clock).sync(g);
      expect(blocker.focus, isNotNull);
      clock.advance(const Duration(minutes: 61));
      await g.stopTimer();
      expect(g.state.debt!.isPaid, isTrue);
      expect(g.focusBlock, isNull);
    });

    test('a penalty block left running counts only to midnight', () async {
      final g = await awaken(SystemKind.focus);
      await nextDay(g);
      clock.set(g.today.at(23 * 60 + 30));
      await g.startPenaltyBlock();
      clock.set(g.today.addDays(1).at(1 * 60));
      await g.tick();
      expect(g.game.timer, isNull);
      expect(
        g.game.log
            .lastWhere((e) => e.type == 'penalty_block_ended')
            .data['minutes'],
        30,
      );
    });

    test('saves from before penalty kinds still load as exercise', () {
      final debt = debtFromJson({
        'dueDay': '2026-10-20',
        'pushupsOwed': 50,
        'squatsOwed': 0,
        'pushupsDone': 10,
        'squatsDone': 0,
      })!;
      expect(debt.kind, PenaltyKind.exercise);
      expect((debt.primaryOwed, debt.primaryDone), (50, 10));
    });
  });

  group('issued quests are frozen', () {
    test('today\'s quest is snapshotted and judged as issued', () async {
      final g = await awaken(SystemKind.personality);
      await g.tick();
      final snap = g.systems!.issued[g.today]!;
      expect(snap.map((q) => q.id), ['pages', 'journal', 'hello']);
      // A snapshot that differs from the catalogue wins (an app update
      // must never change a quest already issued).
      final altered = g.systems!.copyWith(
        issued: {
          g.today: [snap.first],
        },
      );
      await store.save(g.game.copyWith(systems: altered));
      final h = (await GameService.load(
        store: store,
        clock: clock,
        meter: meter,
      ))!;
      expect(h.todaysTasks.map((t) => t.id), ['pages']);
      await h.setProgress('pages', 10);
      final events = await nextDay(h);
      expect(events.whereType<QuestCleared>(), hasLength(1));
    });

    test('old snapshots are dropped after 40 days', () async {
      final g = await awaken(SystemKind.fitness);
      await clearDays(g, 45);
      final days = g.systems!.issued.keys.toList()..sort();
      expect(days.length, lessThanOrEqualTo(41));
      expect(days.last, g.today);
    });
  });
}

class _SpyMeter implements UsageMeter {
  _SpyMeter(this.ends, this.minutes);
  final List<DateTime> ends;
  final int minutes;

  @override
  Future<int?> minutesUsed(Set<String> p, DateTime from, DateTime to) async {
    ends.add(to);
    return minutes;
  }
}
