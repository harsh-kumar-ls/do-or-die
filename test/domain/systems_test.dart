import 'package:do_or_die/domain/day.dart';
import 'package:do_or_die/domain/progression.dart';
import 'package:do_or_die/domain/system_catalogue.dart';
import 'package:do_or_die/domain/systems.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const monday = DayKey(2026, 10, 26);
  final tuesday = monday.addDays(1);

  group('catalogue', () {
    test(
      'every System has a daily quest and a Rank Trial for every rank E to S',
      () {
        for (final kind in SystemKind.values) {
          final spec = systemCatalogue[kind]!;
          expect(spec.kind, kind);
          for (final rank in Rank.values) {
            final r = spec.at(rank);
            expect(
              r.daily,
              isNotEmpty,
              reason: '${kind.name} ${rank.name} daily',
            );
            expect(r.trial.summary, isNotEmpty);
            if (rank == Rank.s) {
              expect(
                r.trial.holdDays,
                30,
                reason: 'S is held, not a one-day trial',
              );
            } else {
              expect(
                r.trial.items,
                isNotEmpty,
                reason: '${kind.name} ${rank.name} trial',
              );
              expect(r.trial.holdDays, 0);
            }
          }
        }
      },
    );

    test('ids are unique within each daily quest and each trial', () {
      for (final spec in systemCatalogue.values) {
        for (final r in spec.ranks.values) {
          for (final list in [r.daily, r.trial.items]) {
            final ids = list.map((i) => i.id).toList();
            expect(ids.toSet().length, ids.length);
          }
        }
      }
    });

    test(
      'a quest item that appears at consecutive ranks never gets easier',
      () {
        for (final spec in systemCatalogue.values) {
          for (var i = 1; i < Rank.values.length; i++) {
            final lower = {
              for (final q in spec.at(Rank.values[i - 1]).daily) q.id: q,
            };
            for (final q in spec.at(Rank.values[i]).daily) {
              final prev = lower[q.id];
              if (prev == null || prev.kind != q.kind) continue;
              if (q.lowerIsBetter) {
                expect(
                  q.target,
                  lessThanOrEqualTo(prev.target),
                  reason: '${spec.name} ${q.id}',
                );
              } else {
                expect(
                  q.target,
                  greaterThanOrEqualTo(prev.target),
                  reason: '${spec.name} ${q.id}',
                );
              }
            }
          }
        }
      },
    );

    test('Systems train the stats in the PRD, including the new CHA', () {
      expect(fitnessSystem.stats, [Stat.strength, Stat.vitality]);
      expect(personalitySystem.stats, [Stat.intellect, Stat.charisma]);
      expect(focusSystem.stats, [Stat.discipline]);
    });

    test('planks are in seconds, as in the PRD (30, 45, 60)', () {
      int plank(Rank r) =>
          fitnessSystem.at(r).daily.firstWhere((q) => q.id == 'plank').target;
      expect(plank(Rank.d), 30);
      expect(plank(Rank.c), 45);
      expect(plank(Rank.b), 60);
    });
  });

  group('one System at a time', () {
    test('the first System can be chosen at a placement rank', () {
      final p = const SystemProgress().choose(SystemKind.fitness, Rank.d);
      expect(p.active, SystemKind.fitness);
      expect(p.rankOf(SystemKind.fitness), Rank.d);
      expect(p.canChooseSystem, isFalse);
    });

    test(
      'no switching: a second System is refused until the first is complete',
      () {
        final p = const SystemProgress().choose(SystemKind.focus, Rank.e);
        expect(() => p.choose(SystemKind.fitness, Rank.e), throwsStateError);
      },
    );

    test('placement can start at E, D or C, never higher', () {
      for (final ok in [Rank.e, Rank.d, Rank.c]) {
        expect(
          const SystemProgress()
              .choose(SystemKind.fitness, ok)
              .rankOf(SystemKind.fitness),
          ok,
        );
      }
      for (final no in [Rank.b, Rank.a, Rank.s]) {
        expect(
          () => const SystemProgress().choose(SystemKind.fitness, no),
          throwsArgumentError,
        );
      }
    });
  });

  group('ranks', () {
    test('clearing a Dungeon raises the rank by exactly one', () {
      var p = const SystemProgress().choose(SystemKind.fitness, Rank.e);
      p = p.rankUp();
      expect(p.rankOf(SystemKind.fitness), Rank.d);
      p = p.rankUp();
      expect(p.rankOf(SystemKind.fitness), Rank.c);
    });

    test('there is no way to lower a rank', () {
      // The public API offers only rankUp; walking all the way up never
      // produces a lower rank at any step.
      var p = const SystemProgress().choose(SystemKind.personality, Rank.e);
      var last = Rank.e;
      for (var i = 0; i < 5; i++) {
        p = p.rankUp();
        final now = p.rankOf(SystemKind.personality)!;
        expect(now.index, greaterThan(last.index));
        last = now;
      }
      expect(last, Rank.s);
    });

    test('clearing the S trial completes the System; then, and only then, a new one can be chosen', () {
      var p = const SystemProgress().choose(SystemKind.focus, Rank.c);
      p = p.rankUp().rankUp().rankUp(); // C -> B -> A -> S
      expect(p.rankOf(SystemKind.focus), Rank.s);
      expect(p.canChooseSystem, isFalse);

      p = p.rankUp(); // S trial (hold 30 days) cleared
      expect(p.completed, contains(SystemKind.focus));
      expect(p.rankOf(SystemKind.focus), Rank.s, reason: 'S kept for good');
      expect(p.canChooseSystem, isTrue);
      expect(p.dailyQuest(systemCatalogue, monday), isEmpty);

      p = p.choose(SystemKind.fitness, Rank.e);
      expect(p.active, SystemKind.fitness);
      expect(p.rankOf(SystemKind.focus), Rank.s);
      expect(() => p.choose(SystemKind.focus, Rank.e), throwsStateError);
    });
  });

  group('reduction valve', () {
    test('applies from tomorrow, never today', () {
      final p = const SystemProgress()
          .choose(SystemKind.fitness, Rank.e)
          .setReduction(monday, 20);
      expect(p.reductionOn(monday), 0);
      expect(p.reductionOn(tuesday), 20);
    });

    test('works on at most 6 days in any 30, then the full quest returns', () {
      final p = const SystemProgress()
          .choose(SystemKind.fitness, Rank.e)
          .setReduction(monday, 20);
      final reduced = [
        for (var i = 1; i <= 40; i++)
          if (p.reductionOn(monday.addDays(i)) > 0) i,
      ];
      // Days 1-6 reduced; the window frees a day again on day 31.
      expect(reduced.take(6), [1, 2, 3, 4, 5, 6]);
      expect(reduced.where((i) => i > 6 && i <= 30), isEmpty);
      expect(reduced.where((i) => i > 30), [31, 32, 33, 34, 35, 36]);
      expect(p.reducedDaysUsed(monday.addDays(10)), 6);
      expect(p.settingOn(monday.addDays(10)), 20);
    });

    test('a past day keeps its answer when the valve is changed later', () {
      final base = const SystemProgress()
          .choose(SystemKind.fitness, Rank.e)
          .setReduction(monday, 10);
      final later = base.setReduction(monday.addDays(3), 0);
      for (var i = 1; i <= 3; i++) {
        expect(
          later.reductionOn(monday.addDays(i)),
          base.reductionOn(monday.addDays(i)),
        );
      }
      expect(later.reductionOn(monday.addDays(5)), 0);
    });

    test('is capped at 20%', () {
      final p = const SystemProgress()
          .choose(SystemKind.fitness, Rank.e)
          .setReduction(monday, 60);
      expect(p.reductionOn(tuesday), maxQuestReduction);
    });

    test('lowers targets and raises caps', () {
      var p = const SystemProgress()
          .choose(SystemKind.fitness, Rank.e)
          .setReduction(monday, 20);
      final fit = {
        for (final q in p.dailyQuest(systemCatalogue, tuesday)) q.id: q.target,
      };
      expect(fit['pushups'], 8); // 10 -> 8
      expect(fit['squats'], 12); // 15 -> 12
      p = const SystemProgress()
          .choose(SystemKind.focus, Rank.c)
          .setReduction(monday, 20);
      final cap = p
          .dailyQuest(systemCatalogue, tuesday)
          .firstWhere((q) => q.id == 'social');
      expect(
        cap.target,
        48,
        reason: 'a 40-minute cap becomes 48: easier means more allowed',
      );
    });

    test('a checkbox cannot be reduced', () {
      const item = QuestItem(
        'meals',
        'No phone at meals',
        QuestKind.checkbox,
        1,
      );
      expect(item.reducedBy(20), item);
    });

    test('a new System starts without any reduction', () {
      var p = const SystemProgress().choose(SystemKind.focus, Rank.c);
      p = p.rankUp().rankUp().rankUp().rankUp(); // complete Focus
      p = p.setReduction(monday, 20).choose(SystemKind.fitness, Rank.e);
      expect(p.reductionOn(tuesday), 0);
    });
  });

  test('the daily quest follows the active System and rank', () {
    final p = const SystemProgress().choose(SystemKind.personality, Rank.d);
    final ids = p.dailyQuest(systemCatalogue, monday).map((q) => q.id);
    expect(ids, ['pages', 'journal', 'greet']);
  });
}
