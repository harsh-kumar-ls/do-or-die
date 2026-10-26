import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/dungeon.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/system_catalogue.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:flutter_test/flutter_test.dart';

const start = DayKey(2026, 11, 1);
DateTime noonOf(DayKey d) => d.at(12 * 60);

/// A fresh Fitness E state started on [start].
SystemsState fresh() =>
    const SystemsState(progress: SystemProgress())
        .choose(SystemKind.fitness, Rank.e, start);

/// Closes [days] consecutive days from [from] with the given verdicts.
(SystemsState, List<SystemEvent>) run(
  SystemsState s,
  DayKey from,
  List<bool> verdicts, {
  bool dryRun = false,
}) {
  final events = <SystemEvent>[];
  for (final (i, cleared) in verdicts.indexed) {
    final day = from.addDays(i);
    final r = s.afterDayClosed(
      day: day,
      cleared: cleared,
      dryRun: dryRun,
      now: day.addDays(1).at(0),
    );
    s = r.$1;
    events.addAll(r.$2);
  }
  return (s, events);
}

void main() {
  group('Gate', () {
    test('opens the moment 21 of the last 30 days are cleared, not before', () {
      var (s, events) = run(fresh(), start, List.filled(20, true));
      expect(s.gate, isNull);
      expect(events, isEmpty);

      (s, events) = run(s, start.addDays(20), [true]);
      expect(events.single, isA<GateOpened>());
      expect(s.gate!.from, Rank.e);
    });

    test('failed days in between still allow 21 of 30', () {
      // 21 cleared with 9 failures spread through 30 days.
      final pattern = [for (var i = 0; i < 30; i++) i % 10 < 7];
      final (s, events) = run(fresh(), start, pattern);
      expect(pattern.where((c) => c).length, 21);
      expect(events.whereType<GateOpened>(), hasLength(1));
      expect(s.gate, isNotNull);
    });

    test('only the last 30 days count', () {
      // 20 cleared, then 15 failed: the early clears fall out of the window.
      var (s, _) = run(fresh(), start, [
        ...List.filled(20, true),
        ...List.filled(15, false),
      ]);
      final day = start.addDays(35);
      (s, _) = run(s, day, [true]);
      expect(s.clearedInWindow(day), lessThan(DungeonRules.clearedNeeded));
      expect(s.gate, isNull);
    });

    test('dry-run days never count', () {
      final (s, events) = run(
        fresh(),
        start,
        List.filled(25, true),
        dryRun: true,
      );
      expect(s.history, isEmpty);
      expect(events, isEmpty);
    });

    test('an unentered Gate expires after 48 hours and reopens 3 days later if still earned', () {
      var (s, _) = run(fresh(), start, List.filled(21, true));
      final opened = s.gate!.openedAt;

      final (afterExpiry, ev) = s.expireGate(
        opened.add(const Duration(hours: 48)),
      );
      expect(ev.single, isA<GateExpired>());
      expect(afterExpiry.gate, isNull);
      s = afterExpiry;

      // It expired at midnight after day 23, so it is blocked for 3 days
      // from then: closing days 22-25 opens nothing.
      final expiredOn = DayKey.fromDateTime(
        opened.add(DungeonRules.gateLifetime),
      );
      expect(
        afterExpiry.gateBlockedUntil,
        expiredOn.addDays(DungeonRules.reopenAfterExpiry),
      );
      var r = run(s, start.addDays(21), [true, true, true, true]);
      expect(r.$2.whereType<GateOpened>(), isEmpty);
      // Closing the day before the block ends opens it again.
      r = run(r.$1, start.addDays(25), [true]);
      expect(r.$2.whereType<GateOpened>(), hasLength(1));
    });

    test('a Gate does not expire before its 48 hours', () {
      final (s, _) = run(fresh(), start, List.filled(21, true));
      final (same, ev) = s.expireGate(
        s.gate!.openedAt.add(const Duration(hours: 47)),
      );
      expect(ev, isEmpty);
      expect(same.gate, isNotNull);
    });
  });

  group('Dungeon', () {
    (SystemsState, DayKey) entered() {
      final (s, _) = run(fresh(), start, List.filled(21, true));
      final enterAt = s.gate!.openedAt.add(const Duration(hours: 2));
      final (inside, event) = s.enter(enterAt)!;
      expect(event, isA<DungeonEntered>());
      return (inside, DayKey.fromDateTime(enterAt).addDays(1));
    }

    test('floor 1 is the day after entering; floors are consecutive', () {
      final (s, f1) = entered();
      expect(s.floorOn(f1), 1);
      expect(s.floorOn(f1.addDays(1)), 2);
      expect(s.floorOn(f1.addDays(2)), 3);
      expect(s.floorOn(f1.addDays(3)), 0);
      expect(s.floorOn(f1.addDays(-1)), 0);
      expect(s.gate, isNull);
    });

    test('a Gate past its 48 hours cannot be entered', () {
      final (s, _) = run(fresh(), start, List.filled(21, true));
      expect(s.enter(s.gate!.openedAt.add(DungeonRules.gateLifetime)), isNull);
    });

    test('floors 1 and 2 are the daily quest +25% and +50%; floor 3 is the Rank Trial', () {
      final (s, f1) = entered();
      final daily = {
        for (final q in fitnessSystem.at(Rank.e).daily) q.id: q.target,
      };
      final floor1 = {
        for (final q in s.questFor(systemCatalogue, f1)) q.id: q.target,
      };
      final floor2 = {
        for (final q in s.questFor(systemCatalogue, f1.addDays(1)))
          q.id: q.target,
      };
      expect(floor1['pushups'], (daily['pushups']! * 1.25).ceil());
      expect(floor2['pushups'], (daily['pushups']! * 1.5).ceil());
      expect(
        s.questFor(systemCatalogue, f1.addDays(2)).map((q) => q.id),
        fitnessSystem.at(Rank.e).trial.items.map((q) => q.id),
      );
    });

    test('a harder Focus floor lowers the screen-time cap', () {
      var p = const SystemsState(progress: SystemProgress())
          .choose(SystemKind.focus, Rank.d, start);
      final (opened, _) = run(p, start, List.filled(21, true));
      final (inside, _) = opened.enter(opened.gate!.openedAt)!;
      final f1 = inside.dungeon!.firstFloor;
      final cap = inside.questFor(systemCatalogue, f1).single;
      expect(cap.lowerIsBetter, isTrue);
      expect(cap.target, 45, reason: '60-minute cap, 25% harder');
      p = inside;
      expect(p.questFor(systemCatalogue, f1.addDays(1)).single.target, 30);
    });

    test('floor 2 has an 18:00 deadline; other days have none', () {
      final (s, f1) = entered();
      expect(s.deadlineOn(f1), isNull);
      expect(s.deadlineOn(f1.addDays(1)), f1.addDays(1).at(18 * 60));
      expect(s.deadlineOn(f1.addDays(2)), isNull);
    });

    test('clearing all three floors ranks up, awards a title and resets the window', () {
      final (s, f1) = entered();
      final (after, events) = run(s, f1, [true, true, true]);
      expect(events.whereType<FloorCleared>().map((e) => e.floor), [1, 2]);
      final cleared = events.whereType<DungeonCleared>().single;
      expect(cleared.newRank, Rank.d);
      expect(after.rank, Rank.d);
      expect(after.dungeon, isNull);
      expect(after.titles.single, contains('Fitness D'));
      expect(after.countFrom, f1.addDays(3));
      expect(after.clearedInWindow(f1.addDays(3)), 0);
    });

    test('Dungeon days never count toward the next Gate', () {
      final (s, f1) = entered();
      final (after, _) = run(s, f1, [true, true, true]);
      expect(after.history.keys.where((d) => !d.isBefore(f1)), isEmpty);
    });

    test('failing any floor ends the Dungeon: Dungeon Penalty next day, Gate shut 7 days, rank kept', () {
      for (final failOn in [1, 2, 3]) {
        final (s, f1) = entered();
        final verdicts = [for (var f = 1; f <= failOn; f++) f != failOn];
        final (after, events) = run(s, f1, verdicts);
        final failDay = f1.addDays(failOn - 1);
        expect(events.whereType<DungeonFailed>().single.floor, failOn);
        expect(after.dungeon, isNull);
        expect(after.rank, Rank.e, reason: 'no rank loss');
        expect(after.dungeonPenaltyDay, failDay.addDays(1));
        expect(after.gateBlockedUntil, failDay.addDays(8));
      }
    });

    test('after a failure the Gate cannot reopen for 7 days, then can', () {
      final (s, f1) = entered();
      var (after, _) = run(s, f1, [false]);
      final from = f1.addDays(1);
      var r = run(after, from, List.filled(6, true));
      expect(
        r.$2.whereType<GateOpened>(),
        isEmpty,
        reason: 'still within the 7 days',
      );
      r = run(r.$1, from.addDays(6), [true]);
      expect(r.$2.whereType<GateOpened>(), hasLength(1));
      after = r.$1;
      expect(after.gate, isNotNull);
    });
  });

  group('S rank', () {
    SystemsState atS() {
      var s = const SystemsState(progress: SystemProgress())
          .choose(SystemKind.focus, Rank.c, start);
      s = s.copyWith(progress: s.progress.rankUp().rankUp().rankUp()); // C -> S
      expect(s.rank, Rank.s);
      return s;
    }

    test('no Gate ever opens at S', () {
      final (_, events) = run(atS(), start, List.filled(29, true));
      expect(events.whereType<GateOpened>(), isEmpty);
    });

    test('30 consecutive cleared days complete the System', () {
      final (s, events) = run(atS(), start, List.filled(30, true));
      expect(
        events.whereType<SystemCompleted>().single.system,
        SystemKind.focus,
      );
      expect(s.progress.completed, contains(SystemKind.focus));
      expect(s.progress.canChooseSystem, isTrue);
    });

    test('a failed day restarts the 30-day hold', () {
      final (s, events) = run(atS(), start, [
        ...List.filled(20, true),
        false,
        ...List.filled(29, true),
      ]);
      expect(events.whereType<SystemCompleted>(), isEmpty);
      expect(s.sHold, 29);
    });
  });

  test('a completed System ignores further days', () {
    var s = const SystemsState(progress: SystemProgress())
        .choose(SystemKind.focus, Rank.c, start);
    s = s.copyWith(progress: s.progress.rankUp().rankUp().rankUp().rankUp());
    final (same, events) = run(s, start, List.filled(5, true));
    expect(events, isEmpty);
    expect(identical(same, s), isTrue);
  });
}
