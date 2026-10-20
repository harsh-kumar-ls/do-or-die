import 'dart:math';

import 'package:do_or_die/domain/config.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/penalty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = PenaltyCalculator(GameConfig());

  group('push-ups and squats by level', () {
    test('level 1 is 50 push-ups, +5 per level', () {
      expect(calc.pushupsForLevel(1), 50);
      expect(calc.pushupsForLevel(10), 95);
      expect(calc.pushupsForLevel(11), 100);
    });

    test('push-ups cap at 150 from level 21', () {
      expect(calc.pushupsForLevel(21), 150);
      expect(calc.pushupsForLevel(22), 150);
      expect(calc.pushupsForLevel(60), 150);
    });

    test('no squats until push-ups pass the cap', () {
      expect(calc.squatsForLevel(1), 0);
      expect(calc.squatsForLevel(21), 0);
    });

    test('squats start at 50 on level 22 and rise +5 per level', () {
      expect(calc.firstSquatLevel, 22);
      expect(calc.squatsForLevel(22), 50);
      expect(calc.squatsForLevel(23), 55);
      expect(calc.squatsForLevel(30), 90);
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
      var debt = const ExerciseDebt(
        dueDay: day,
        pushupsOwed: 50,
        squatsOwed: 0,
      );
      debt = debt.record(pushups: 40);
      expect(debt.pushupsRemaining, 10);
      debt = debt.record(pushups: 30);
      expect(debt.pushupsRemaining, 0);
      expect(debt.pushupsDone, 50);
      expect(debt.isPaid, isTrue);
    });

    test('negative input is ignored', () {
      final debt = const ExerciseDebt(
        dueDay: day,
        pushupsOwed: 50,
        squatsOwed: 0,
      ).record(pushups: -20);
      expect(debt.pushupsRemaining, 50);
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
