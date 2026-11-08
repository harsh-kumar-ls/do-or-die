import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/engine.dart';
import 'package:do_or_die/domain/penalty.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:do_or_die/platform/usage_meter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day1 = DayKey(2026, 10, 19);
  late FixedClock clock;
  late MemoryGameStore store;

  setUp(() {
    clock = FixedClock(day1.at(9 * 60));
    store = MemoryGameStore();
  });

  Future<GameService> focus({int lockStart = 18 * 60}) => GameService.awaken(
    store: store,
    system: SystemKind.focus,
    placement: Rank.e,
    blockedPackages: const {'com.instagram.android'},
    dryRunDays: 0,
    lockStartMinute: lockStart,
    clock: clock,
    random: Random(1),
  );

  group('the chosen lock time', () {
    test('a failed day locks at the chosen time the next day', () async {
      final g = await focus(lockStart: 19 * 60);
      clock.set(day1.addDays(1).at(8 * 60));
      await g.tick();
      final lock = g.state.lock!;
      expect(lock.start, day1.addDays(1).at(19 * 60));
      expect(lock.duration, const Duration(hours: 4));
    });

    test('a new lock time applies from the day after tomorrow', () async {
      final g = await focus();
      await g.setLockStart(12 * 60);
      clock.set(day1.addDays(1).at(8 * 60)); // day 1 failed
      await g.tick();
      expect(
        g.state.lock!.start,
        day1.addDays(1).at(18 * 60),
        reason: 'tomorrow keeps the old time',
      );
      clock.set(day1.addDays(2).at(8 * 60)); // day 2 failed
      await g.tick();
      expect(g.state.lock!.start, day1.addDays(2).at(12 * 60));
      expect(g.lockStartMinute, 12 * 60);
    });

    test('a rest period changed on a failing evening never shrinks the '
        'next lock', () async {
      final g = await focus();
      clock.set(day1.at(22 * 60));
      // Rest from 17:00 would leave no room for an 18:00 lock tomorrow.
      expect(
        await g.setSleepWindow(
          const SleepWindow(startMinute: 17 * 60, endMinute: 5 * 60),
        ),
        isTrue,
      );
      clock.set(day1.addDays(1).at(8 * 60));
      await g.tick();
      expect(g.state.lock!.duration, const Duration(hours: 4));
      expect(g.state.lock!.start, day1.addDays(1).at(18 * 60));
    });

    test('a rest period leaving under 12 waking hours is refused', () async {
      final g = await focus();
      expect(
        await g.setSleepWindow(
          const SleepWindow(startMinute: 18 * 60, endMinute: 7 * 60),
        ),
        isFalse,
      );
      expect(g.game.pendingSleep, isNull);
    });
  });

  group('contesting a verdict', () {
    Future<GameService> failedYesterday() async {
      final g = await focus();
      clock.set(day1.addDays(1).at(8 * 60));
      await g.tick();
      expect(g.penaltyInEffect, isTrue);
      return g;
    }

    test(
      'cancels the lock and the debt; the failure stays on record',
      () async {
        final g = await failedYesterday();
        expect(g.contestableDay, day1);
        expect(
          await g.contestVerdict('short'),
          isFalse,
          reason: 'needs a reason',
        );
        expect(
          await g.contestVerdict('Phone died at 21:00, read on paper'),
          isTrue,
        );
        expect(g.penaltyInEffect, isFalse);
        clock.set(day1.addDays(1).at(19 * 60));
        expect(g.isLockActive(), isFalse);
        expect(
          g.game.log.where((e) => e.type == 'quest_failed'),
          hasLength(1),
          reason: 'the verdict itself is not erased',
        );
        expect(g.contestsUsed, 1);
      },
    );

    test('only one contest in any 14 days', () async {
      final g = await failedYesterday();
      expect(
        await g.contestVerdict('Phone died at 21:00, read on paper'),
        isTrue,
      );
      clock.set(day1.addDays(2).at(8 * 60)); // day 2 failed too
      await g.tick();
      expect(g.penaltyInEffect, isTrue);
      expect(g.contestableDay, isNull);
      expect(g.contestCooldownUntil, day1.addDays(15));
      expect(await g.contestVerdict('Another long enough reason'), isFalse);
    });

    test('no contest without a failed verdict', () async {
      final g = await focus();
      expect(g.contestableDay, isNull);
      expect(await g.contestVerdict('Nothing to contest here'), isFalse);
    });
  });

  group('time zones', () {
    Future<String?> london() async => 'Europe/London';

    test(
      'moving to a zone further west can never push the deadline later',
      () async {
        final g = await focus();
        // The day was issued in Tokyo, 6 hours further east than here: there,
        // 21:00 here is already 03:00 tomorrow, so the day must be judged.
        final east = clock.now().timeZoneOffset.inMinutes + 6 * 60;
        await store.save(
          g.game.copyWith(zoneOffsetMinutes: east, zoneId: 'Asia/Tokyo'),
        );
        final h = (await GameService.load(
          store: store,
          clock: clock,
          zoneId: london,
        ))!;
        clock.set(day1.at(21 * 60));
        await h.tick();
        expect(h.state.lastClosedDay, day1);
      },
    );

    test('a later day follows the new zone and the change is logged', () async {
      final g = await focus();
      final east = clock.now().timeZoneOffset.inMinutes + 6 * 60;
      await store.save(
        g.game.copyWith(zoneOffsetMinutes: east, zoneId: 'Asia/Tokyo'),
      );
      final h = (await GameService.load(
        store: store,
        clock: clock,
        zoneId: london,
      ))!;
      clock.set(day1.addDays(1).at(9 * 60));
      await h.tick();
      expect(h.game.zoneOffsetMinutes, clock.now().timeZoneOffset.inMinutes);
      expect(h.game.zoneId, 'Europe/London');
      expect(h.game.log.where((e) => e.type == 'zone_changed'), hasLength(1));
    });

    test('daylight saving ending (same zone, offset back an hour) never '
        'judges the day early', () async {
      Future<String?> berlin() async => 'Europe/Berlin';
      final g = await focus();
      // The day began at summer time, an hour ahead of the offset now.
      final summer = clock.now().timeZoneOffset.inMinutes + 60;
      await store.save(
        g.game.copyWith(zoneOffsetMinutes: summer, zoneId: 'Europe/Berlin'),
      );
      final h = (await GameService.load(
        store: store,
        clock: clock,
        zoneId: berlin,
      ))!;
      clock.set(day1.at(23 * 60 + 30));
      await h.tick();
      expect(h.state.lastClosedDay, isNull, reason: 'still open at 23:30');
      expect(h.state.isOpen(day1), isTrue);
      expect(h.game.log.where((e) => e.type == 'zone_changed'), isEmpty);
    });

    test(
      'on the real DST nights (run with TZ=Europe/Berlin or '
      'TZ=America/New_York) the day stays open until local midnight',
      () async {
        for (final (date, zone) in [
          (DateTime(2026, 10, 25), 'Europe/Berlin'),
          (DateTime(2026, 11, 1), 'America/New_York'),
        ]) {
          final day = DayKey.fromDateTime(date);
          final c = FixedClock(day.at(9 * 60));
          final g = await GameService.awaken(
            store: MemoryGameStore(),
            system: SystemKind.focus,
            placement: Rank.e,
            blockedPackages: const {'com.instagram.android'},
            dryRunDays: 0,
            clock: c,
            random: Random(1),
            zoneId: () async => zone,
          );
          await g.tick();
          c.set(day.at(23 * 60 + 10));
          await g.tick();
          expect(g.state.isOpen(day), isTrue, reason: '$zone at 23:10');
          expect(g.state.lastClosedDay, isNull);
        }
      },
    );

    test('instants are saved in UTC and read back unchanged', () async {
      final g = await focus();
      clock.set(day1.addDays(1).at(8 * 60));
      await g.tick();
      final lock = g.state.lock!;
      final raw = g.game.toJson()['state'] as Map;
      expect((raw['lock'] as Map)['start'], endsWith('Z'));
      final h = (await GameService.load(store: store, clock: clock))!;
      expect(h.state.lock!.start, lock.start);
    });
  });

  group('no easy escapes', () {
    test(
      'switching System on a failing evening keeps that day\'s penalty',
      () async {
        final g = await focus();
        clock.set(day1.at(22 * 60));
        expect(await g.chooseSystem(SystemKind.fitness, Rank.e), isTrue);
        clock.set(day1.addDays(1).at(8 * 60));
        await g.tick();
        // Day 1 was a Focus day: its phone-free block is still owed.
        expect(g.state.debt!.kind, PenaltyKind.focus);
        expect(g.state.debt!.primaryOwed, 60);
      },
    );

    test('an unfinished live day can not be escaped by restarting after '
        '18:00', () async {
      final g = await focus();
      clock.set(day1.at(19 * 60));
      expect(g.verdictPending, isTrue);
      expect(await g.abandon(), isFalse);
      clock.set(day1.at(10 * 60));
      expect(await g.abandon(), isTrue);
    });

    test('one dry run per install: a restarted game gets none', () async {
      expect(await store.dryRunUsed(), isFalse);
      final g = await focus();
      await g.abandon();
      expect(await store.dryRunUsed(), isTrue);
    });
  });

  test('a game without a dry run, begun at 23:40, starts tomorrow: no '
      'verdict, lock or debt for its first night', () async {
    clock.set(day1.at(23 * 60 + 40));
    final g = await GameService.awaken(
      store: store,
      system: SystemKind.focus,
      placement: Rank.e,
      blockedPackages: const {'com.instagram.android'},
      dryRunDays: 0,
      startTomorrow: true,
      clock: clock,
      random: Random(1),
    );
    expect(g.todaysTasks, isEmpty);
    clock.set(day1.addDays(1).at(9 * 60));
    final events = await g.tick();
    expect(events.whereType<QuestFailed>(), isEmpty);
    expect(g.state.lock, isNull);
    expect(g.state.debt, isNull);
    expect(g.todaysTasks, isNotEmpty);
    expect(g.systems!.history, isEmpty, reason: 'no quest day: no Gate credit');
  });

  test(
    'three near misses in a row are counted for the System notice',
    () async {
      final g = await GameService.awaken(
        store: store,
        system: SystemKind.focus,
        placement: Rank.d, // social-media cap of 60 minutes
        blockedPackages: const {'com.instagram.android'},
        dryRunDays: 0,
        clock: clock,
        random: Random(1),
        meter: _Meter(63),
      );
      for (var i = 1; i <= 3; i++) {
        clock.set(day1.addDays(i).at(9 * 60));
        await g.tick();
      }
      expect(g.nearMissStreak, 3);
      expect(g.state.lock, isNull);
    },
  );

  test('old trials can be deleted; the dry run stays used', () async {
    final g = await focus();
    clock.set(day1.at(10 * 60));
    expect(await g.abandon(), isTrue);
    expect(await store.archiveCount(), 1);
    await store.deleteArchives();
    expect(await store.archiveCount(), 0);
    expect(await store.dryRunUsed(), isTrue);
  });
}

class _Meter implements UsageMeter {
  _Meter(this.minutes);
  final int minutes;

  @override
  Future<int?> minutesUsed(Set<String> p, DateTime from, DateTime to) async =>
      minutes;
}
