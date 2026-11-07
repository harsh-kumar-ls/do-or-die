import 'dart:math';

import 'day.dart';
import 'progression.dart';

/// A training path the System guides the user through. See SYSTEMS_PRD.md.
enum SystemKind { fitness, personality, focus }

/// How a quest item is measured.
enum QuestKind {
  /// Done or not done.
  checkbox,

  /// Minutes spent (reading, deep work, walking). Higher is better.
  timer,

  /// A count (reps, pages, conversations). Higher is better.
  counter,

  /// Metres covered. Higher is better.
  distance,

  /// Minutes of social-media use allowed. **Lower is better.**
  screenCap,

  /// Length in minutes of the longest phone-free block. Higher is better.
  phoneFree,
}

class QuestItem {
  const QuestItem(this.id, this.label, this.kind, this.target);

  final String id;
  final String label;
  final QuestKind kind;

  /// Minutes, count or metres, depending on [kind]. 1 for a checkbox.
  final int target;

  bool get lowerIsBetter => kind == QuestKind.screenCap;

  /// The item made easier by [percent] (0-20): targets drop, caps rise.
  /// A checkbox can't be reduced.
  QuestItem reducedBy(int percent) {
    if (percent <= 0 || kind == QuestKind.checkbox) return this;
    final next = lowerIsBetter
        ? (target * (100 + percent) / 100).ceil()
        : max(1, (target * (100 - percent) / 100).floor());
    return QuestItem(id, label, kind, next);
  }

  /// The item made harder by [percent], for Dungeon floors: targets rise,
  /// caps drop. A checkbox stays as it is.
  QuestItem scaledUpBy(int percent) {
    if (percent <= 0 || kind == QuestKind.checkbox) return this;
    final next = lowerIsBetter
        ? max(0, (target * (100 - percent) / 100).floor())
        : (target * (100 + percent) / 100).ceil();
    return QuestItem(id, label, kind, next);
  }

  @override
  bool operator ==(Object other) =>
      other is QuestItem &&
      other.id == id &&
      other.kind == kind &&
      other.target == target &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, kind, target, label);
}

/// The boss of a rank's Dungeon.
class RankTrial {
  const RankTrial(this.summary, this.items, {this.holdDays = 0});

  final String summary;
  final List<QuestItem> items;

  /// For the S rank: consecutive cleared days to hold instead of a one-day
  /// trial. Zero for every other rank.
  final int holdDays;
}

class RankSpec {
  const RankSpec(this.daily, this.trial);
  final List<QuestItem> daily;
  final RankTrial trial;
}

class SystemSpec {
  const SystemSpec(this.kind, this.name, this.tagline, this.stats, this.ranks);

  final SystemKind kind;
  final String name;
  final String tagline;

  /// Stats this System raises.
  final List<Stat> stats;
  final Map<Rank, RankSpec> ranks;

  RankSpec at(Rank r) => ranks[r]!;
}

/// The reduction valve: a System quest can be made up to this much easier.
const maxQuestReduction = 20;

/// The valve works on at most this many days in any [reductionWindowDays]
/// days; past the limit the full quest returns until older reduced days
/// leave the window.
const maxReducedDays = 6;
const reductionWindowDays = 30;

/// A placement test can start a user no higher than this.
const highestPlacement = Rank.c;

/// Which System the user is in, ranks reached, Systems completed, and the
/// reduction valve. Ranks never go down, and there is no switching: a new
/// System can be chosen only once the current one is complete.
class SystemProgress {
  const SystemProgress({
    this.active,
    this.ranks = const {},
    this.completed = const {},
    this.reductions = const [],
  });

  /// The System being trained, or null before the first choice.
  final SystemKind? active;
  final Map<SystemKind, Rank> ranks;

  /// Systems whose S-rank trial has been cleared.
  final Set<SystemKind> completed;

  /// Reduction percentages over time: (effective from, percent), sorted.
  final List<(DayKey, int)> reductions;

  Rank? rankOf(SystemKind k) => ranks[k];

  /// No System is running: none chosen yet, or the current one is
  /// complete (the quest screen then asks for the next one).
  bool get canChooseSystem => active == null || completed.contains(active);

  /// Chooses [kind]: the first System, the next one after completing one,
  /// or a switch (iteration 1: switching is allowed). Ranks never go down:
  /// a System trained before keeps its higher rank.
  SystemProgress choose(SystemKind kind, Rank placement) {
    if (kind == active && !completed.contains(kind)) {
      throw StateError('That System is already active.');
    }
    if (completed.contains(kind)) {
      throw StateError('That System is already complete.');
    }
    if (placement.index > highestPlacement.index) {
      throw ArgumentError(
        'Placement can start at ${highestPlacement.name.toUpperCase()} at most.',
      );
    }
    final before = ranks[kind];
    final rank = before != null && before.index > placement.index
        ? before
        : placement;
    return SystemProgress(
      active: kind,
      ranks: {...ranks, kind: rank},
      completed: completed,
      reductions: const [], // a new System starts with full quests
    );
  }

  /// Called when the active System's Dungeon is cleared: the rank goes up by
  /// one. Clearing the S-rank trial completes the System instead.
  SystemProgress rankUp() {
    final kind = active;
    if (kind == null) throw StateError('No System is active.');
    final current = ranks[kind]!;
    if (current == Rank.s) {
      return SystemProgress(
        active: kind,
        ranks: ranks,
        completed: {...completed, kind},
        reductions: reductions,
      );
    }
    return SystemProgress(
      active: kind,
      ranks: {...ranks, kind: Rank.values[current.index + 1]},
      completed: completed,
      reductions: reductions,
    );
  }

  /// Sets the reduction valve to [percent] (clamped to 0-20), from tomorrow.
  SystemProgress setReduction(DayKey today, int percent) {
    final from = today.addDays(1);
    final value = percent.clamp(0, maxQuestReduction);
    return SystemProgress(
      active: active,
      ranks: ranks,
      completed: completed,
      reductions: [
        ...reductions.where((r) => r.$1.isBefore(from)),
        (from, value),
      ],
    );
  }

  /// The valve setting on [day], before the reduced-day limit.
  int settingOn(DayKey day) {
    var value = 0;
    for (final (from, percent) in reductions) {
      if (!from.isAfter(day)) value = percent;
    }
    return value;
  }

  /// Reduced days granted from the first setting up to [day] inclusive,
  /// oldest first. Depends only on the settings, so a past day always gives
  /// the same answer.
  List<DayKey> _reducedDaysThrough(DayKey day) {
    final granted = <DayKey>[];
    if (reductions.isEmpty) return granted;
    for (var d = reductions.first.$1; !d.isAfter(day); d = d.addDays(1)) {
      if (settingOn(d) == 0) continue;
      final windowStart = d.addDays(1 - reductionWindowDays);
      final inWindow = granted.where((g) => !g.isBefore(windowStart)).length;
      if (inWindow < maxReducedDays) granted.add(d);
    }
    return granted;
  }

  /// The reduction in force on [day]: the valve setting, or 0 once
  /// [maxReducedDays] have been used in the last [reductionWindowDays].
  int reductionOn(DayKey day) {
    final value = settingOn(day);
    if (value == 0) return 0;
    final granted = _reducedDaysThrough(day);
    return granted.isNotEmpty && granted.last == day ? value : 0;
  }

  /// Reduced days used in the [reductionWindowDays] ending on [day].
  int reducedDaysUsed(DayKey day) {
    final windowStart = day.addDays(1 - reductionWindowDays);
    return _reducedDaysThrough(day)
        .where((g) => !g.isBefore(windowStart))
        .length;
  }

  /// Today's daily quest for the active System and rank, with the valve
  /// applied. Empty when no System is active or it is complete.
  List<QuestItem> dailyQuest(
    Map<SystemKind, SystemSpec> catalogue,
    DayKey day,
  ) {
    final kind = active;
    if (kind == null || completed.contains(kind)) return const [];
    final percent = reductionOn(day);
    return [
      for (final item in catalogue[kind]!.at(ranks[kind]!).daily)
        item.reducedBy(percent),
    ];
  }
}
