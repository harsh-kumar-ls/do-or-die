import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/systems.dart';
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

    test('a new lock time applies to locks scheduled after it', () async {
      final g = await focus();
      await g.setLockStart(12 * 60);
      clock.set(day1.addDays(1).at(8 * 60));
      await g.tick();
      expect(g.state.lock!.start, day1.addDays(1).at(12 * 60));
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
    test('moving west can never push the deadline later', () async {
      final g = await focus();
      // Pretend the day was issued in a zone 6 hours further east: there,
      // 21:00 here is already 03:00 tomorrow, so the day must be judged.
      final east = clock.now().timeZoneOffset.inMinutes + 6 * 60;
      await store.save(g.game.copyWith(zoneOffsetMinutes: east));
      final h = (await GameService.load(store: store, clock: clock))!;
      clock.set(day1.at(21 * 60));
      await h.tick();
      expect(h.state.lastClosedDay, day1);
    });

    test('a later day follows the new zone and the change is logged', () async {
      final g = await focus();
      final east = clock.now().timeZoneOffset.inMinutes + 6 * 60;
      await store.save(g.game.copyWith(zoneOffsetMinutes: east));
      final h = (await GameService.load(store: store, clock: clock))!;
      clock.set(day1.addDays(1).at(9 * 60));
      await h.tick();
      expect(h.game.zoneOffsetMinutes, clock.now().timeZoneOffset.inMinutes);
      expect(h.game.log.where((e) => e.type == 'zone_changed'), hasLength(1));
    });

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
}
