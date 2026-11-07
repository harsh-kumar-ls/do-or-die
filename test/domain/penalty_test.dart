import 'dart:math';

import 'package:do_or_die/domain/config.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/penalty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = PenaltyCalculator(GameConfig());

  group('exercise penalty is bounded by the quest (P0 safety)', () {
    test('without a quest volume: 10 push-ups and 15 squats, at any level', () {
      expect(calc.amountsFor(PenaltyKind.exercise, 1), (10, 15));
      expect(calc.amountsFor(PenaltyKind.exercise, 40), (10, 15));
    });

    test('with a quest volume: exactly that, never more', () {
      expect(calc.amountsFor(PenaltyKind.exercise, 30, exercise: (20, 30)), (
        20,
        30,
      ));
    });

    test('a failed Dungeon floor never multiplies exercise', () {
      expect(
        calc.amountsFor(
          PenaltyKind.exercise,
          5,
          multiplier: 2,
          exercise: (10, 15),
        ),
        (10, 15),
      );
    });

    test('reading and focus penalties still scale and double', () {
      expect(calc.amountsFor(PenaltyKind.reading, 1), (20, 1));
      expect(calc.amountsFor(PenaltyKind.reading, 1, multiplier: 2), (40, 2));
      expect(calc.amountsFor(PenaltyKind.focus, 1, multiplier: 2), (120, 0));
    });
  });

  group('lock length by level', () {
    test('4 hours at level 1, +20 minutes per level', () {
      expect(calc.lockMinutesForLevel(1), 240);
      expect(calc.lockMinutesForLevel(2), 260);
      expect(calc.lockMinutesForLevel(10), 420);
    });
  });

  group('exercise debt', () {
    const day = DayKey(2026, 10, 20);

    test('recording reps reduces what is owed and never goes negative', () {
      var debt = const PenaltyDebt(
        dueDay: day,
        primaryOwed: 50,
        secondaryOwed: 0,
      );
      debt = debt.record(primary: 40);
      expect(debt.primaryRemaining, 10);
      debt = debt.record(primary: 30);
      expect(debt.primaryRemaining, 0);
      expect(debt.primaryDone, 50);
      expect(debt.isPaid, isTrue);
    });

    test('negative input is ignored', () {
      final debt = const PenaltyDebt(
        dueDay: day,
        primaryOwed: 50,
        secondaryOwed: 0,
      ).record(primary: -20);
      expect(debt.primaryRemaining, 50);
    });
  });

  group('random lock window', () {
    const scheduler = LockScheduler();
    const sleep = SleepWindow(); // 23:00 to 07:00
    const day = DayKey(2026, 10, 21);

    test('always inside waking hours, with the exact length', () {
      for (var seed = 0; seed < 500; seed++) {
        final w = scheduler.schedule(
          day: day,
          durationMinutes: 240,
          sleep: sleep,
          random: Random(seed),
        )!;
        expect(w.start.isBefore(day.at(7 * 60)), isFalse, reason: 'seed $seed');
        expect(w.end.isAfter(day.at(23 * 60)), isFalse, reason: 'seed $seed');
        expect(w.duration, const Duration(minutes: 240));
        expect(w.clamped, isFalse);
      }
    });

    test('start time actually varies', () {
      final starts = {
        for (var seed = 0; seed < 50; seed++)
          scheduler
              .schedule(
                day: day,
                durationMinutes: 240,
                sleep: sleep,
                random: Random(seed),
              )!
              .start,
      };
      expect(starts.length, greaterThan(10));
    });

    test('a lock longer than the waking day is clamped to it', () {
      final w = scheduler.schedule(
        day: day,
        durationMinutes: 20 * 60,
        sleep: sleep,
        random: Random(1),
      )!;
      expect(w.start, day.at(7 * 60));
      expect(w.end, day.at(23 * 60));
      expect(w.clamped, isTrue);
    });

    test('never starts before notBefore', () {
      final notBefore = DateTime(2026, 10, 21, 15, 30, 20);
      for (var seed = 0; seed < 200; seed++) {
        final w = scheduler.schedule(
          day: day,
          durationMinutes: 240,
          sleep: sleep,
          random: Random(seed),
          notBefore: notBefore,
        )!;
        expect(w.start.isBefore(notBefore), isFalse);
        expect(w.end.isAfter(day.at(23 * 60)), isFalse);
      }
    });

    test('returns null when no waking time is left', () {
      final w = scheduler.schedule(
        day: day,
        durationMinutes: 240,
        sleep: sleep,
        random: Random(1),
        notBefore: DateTime(2026, 10, 21, 23, 30),
      );
      expect(w, isNull);
    });

    test('sleep window after midnight (01:00 to 09:00)', () {
      const lateSleeper = SleepWindow(startMinute: 60, endMinute: 9 * 60);
      for (var seed = 0; seed < 200; seed++) {
        final w = scheduler.schedule(
          day: day,
          durationMinutes: 240,
          sleep: lateSleeper,
          random: Random(seed),
        )!;
        expect(w.start.isBefore(day.at(9 * 60)), isFalse);
        expect(w.end.isAfter(day.addDays(1).at(60)), isFalse);
      }
    });
  });
}
