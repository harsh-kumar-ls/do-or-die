import '../data/log_entry.dart';
import '../data/saved_game.dart';
import '../domain/day.dart';
import '../domain/dungeon.dart';
import '../domain/progression.dart';
import '../domain/systems.dart';

/// How one day went, for the consistency calendar.
enum DayMark { cleared, failed, dryRun, none }

/// A quest item's target when the System began, and now.
class TargetChange {
  const TargetChange(this.label, this.before, this.after, this.unit);
  final String label;
  final int before;
  final int after;
  final String unit;
}

/// The 30-day report, built only from the saved game and its log, so it
/// says exactly what happened. See SYSTEMS_PRD.md section 6.7.
class TrialReport {
  TrialReport._({
    required this.days,
    required this.calendar,
    required this.cleared,
    required this.failed,
    required this.longestStreak,
    required this.currentStreak,
    required this.startRank,
    required this.rank,
    required this.system,
    required this.dungeonsCleared,
    required this.dungeonsFailed,
    required this.gatesOpened,
    required this.titles,
    required this.targets,
    required this.stats,
    required this.level,
    required this.releases,
    this.emergencyExits = 0,
    this.contests = 0,
    this.ruleChanges = 0,
    this.unmeasuredCaps = 0,
    this.nearMisses = 0,
    this.expiredPenalties = 0,
    required this.penaltyZones,
    required this.dungeonPenalties,
    required this.watcherOutages,
    required this.honourConfirmations,
    required this.reducedDays,
    required this.clearedInWindow,
  });

  /// Builds the report for the 30 days ending yesterday (fewer early on).
  factory TrialReport.from(
    SavedGame g,
    DayKey today,
    Map<SystemKind, SystemSpec> catalogue,
  ) {
    final log = g.log;
    Iterable<LogEntry> of(String type) => log.where((e) => e.type == type);

    final verdicts = <DayKey, bool>{};
    for (final e in of('quest_cleared')) {
      verdicts[_day(e)] = true;
    }
    for (final e in of('quest_failed')) {
      verdicts[_day(e)] = false;
    }

    final start = g.state.startDay;
    final lastJudged = today.addDays(-1);
    var from = lastJudged.addDays(-29);
    if (from.isBefore(start)) from = start;
    final calendar = <(DayKey, DayMark)>[];
    for (var d = from; !d.isAfter(lastJudged); d = d.addDays(1)) {
      final v = verdicts[d];
      calendar.add((
        d,
        v == null
            ? DayMark.none
            : !g.isEnforced(d)
            ? DayMark.dryRun
            : v
            ? DayMark.cleared
            : DayMark.failed,
      ));
    }

    // Streaks over every judged day, in order.
    final judged = verdicts.keys.toList()..sort();
    var longest = 0;
    var run = 0;
    for (final d in judged) {
      run = verdicts[d]! ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    var current = 0;
    for (final d in judged.reversed) {
      if (!verdicts[d]!) break;
      current++;
    }

    final sys = g.systems;
    final kind = sys?.active;
    final awakened =
        of('awakened').firstOrNull ?? of('system_chosen').lastOrNull;
    final chosen =
        [
          ...of('awakened'),
          ...of('system_chosen'),
        ].where((e) => e.data['system'] == kind?.name).lastOrNull ??
        awakened;
    final startRank = chosen == null
        ? null
        : Rank.values.byName(chosen.data['placement'] as String);
    final rank = sys?.rank;

    final targets = <TargetChange>[];
    if (kind != null && startRank != null && rank != null) {
      final before = {
        for (final q in catalogue[kind]!.at(startRank).daily) q.id: q,
      };
      for (final q in catalogue[kind]!.at(rank).daily) {
        final b = before[q.id];
        if (b == null || q.kind == QuestKind.checkbox) continue;
        targets.add(TargetChange(q.label, b.target, q.target, _unit(q.kind)));
      }
    }

    var reduced = 0;
    if (sys != null) {
      for (var d = from; !d.isAfter(lastJudged); d = d.addDays(1)) {
        if (sys.progress.reductionOn(d) > 0) reduced++;
      }
    }

    return TrialReport._(
      days: calendar.length,
      calendar: calendar,
      cleared: calendar.where((c) => c.$2 == DayMark.cleared).length,
      failed: calendar.where((c) => c.$2 == DayMark.failed).length,
      longestStreak: longest,
      currentStreak: current,
      startRank: startRank,
      rank: rank,
      system: kind,
      dungeonsCleared: of('dungeon_cleared').length,
      dungeonsFailed: of('dungeon_failed').length,
      gatesOpened: of('gate_opened').length,
      titles: sys?.titles ?? const [],
      targets: targets,
      stats: g.state.stats,
      level: g.state.level,
      releases: of('lock_released').length,
      emergencyExits: of('emergency_exit').length,
      contests: of('verdict_contested').length,
      // Changes that can make the game easier, all of them on the record.
      ruleChanges: [
        'sleep_changed',
        'lock_start_changed',
        'system_switched',
        'reduction_set',
        'block_app_removed',
      ].fold(0, (n, t) => n + of(t).length),
      unmeasuredCaps: of('cap_unmeasured')
          .where((e) => e.data['excused'] == true)
          .length,
      nearMisses: of('quest_near_miss').length,
      expiredPenalties: of('penalty_expired').length,
      // Ordinary Penalty Zones only; Dungeon Penalties are counted apart.
      penaltyZones:
          of('penalty_issued')
              .where((e) => e.data['enforced'] != false)
              .length -
          of('dungeon_failed').length,
      dungeonPenalties: of('dungeon_failed').length,
      watcherOutages:
          of('blocker_offline').length + of('watcher_start_failed').length,
      honourConfirmations: of('progress')
          .where((e) => e.data['honour'] == true)
          .length,
      reducedDays: reduced,
      clearedInWindow: sys?.clearedInWindow(lastJudged) ?? 0,
    );
  }

  static DayKey _day(LogEntry e) {
    final parts = (e.data['day'] as String).split('-').map(int.parse).toList();
    return DayKey(parts[0], parts[1], parts[2]);
  }

  static String _unit(QuestKind k) => switch (k) {
    QuestKind.timer || QuestKind.phoneFree || QuestKind.screenCap => 'min',
    QuestKind.distance => 'm',
    _ => '',
  };

  /// Judged days in the report.
  final int days;
  final List<(DayKey, DayMark)> calendar;
  final int cleared;
  final int failed;
  final int longestStreak;
  final int currentStreak;

  final Rank? startRank;
  final Rank? rank;
  final SystemKind? system;
  final int dungeonsCleared;
  final int dungeonsFailed;
  final int gatesOpened;
  final List<String> titles;
  final List<TargetChange> targets;
  final Map<Stat, int> stats;
  final int level;

  final int releases;

  /// Locks ended with the emergency exit.
  final int emergencyExits;

  /// Verdicts contested.
  final int contests;

  /// Settings changed in a way that could make the game easier.
  final int ruleChanges;

  /// Days whose screen-time limit couldn't be measured and was excused.
  final int unmeasuredCaps;

  /// Days that were nearly cleared (no penalty, no XP).
  final int nearMisses;

  /// Penalties left unpaid when their day ended.
  final int expiredPenalties;
  final int penaltyZones;
  final int dungeonPenalties;
  final int watcherOutages;
  final int honourConfirmations;
  final int reducedDays;
  final int clearedInWindow;

  /// Share of enforced judged days that were cleared, 0-100.
  int get clearRate {
    final n = cleared + failed;
    return n == 0 ? 0 : (cleared * 100 / n).round();
  }

  /// The System's verdict: one cold line, first matching rule wins
  /// (design/claude-design/status.html).
  String get headline {
    if (cleared + failed == 0) return 'Insufficient data. Continue.';
    if (clearRate < 50) {
      return 'Fewer than half the days were cleared. The System expected more.';
    }
    if (releases > penaltyZones + dungeonPenalties) {
      return 'You cleared $clearRate% of days and escaped more locks than you served.';
    }
    if (watcherOutages > 0) {
      return 'Cleared $clearRate%. The lock was down $watcherOutages time${watcherOutages == 1 ? '' : 's'}. That was not an accident.';
    }
    if (honourConfirmations * 100 > (cleared + failed) * 60) {
      return 'Cleared $clearRate%. Most of it rests on your word.';
    }
    return 'Cleared $clearRate%. Nothing to add.';
  }

  /// The headline, what releases cost, and the next Gate.
  List<String> get verdict {
    final lines = <String>[
      headline,
      if (releases > 0)
        '$releases release${releases == 1 ? '' : 's'} taken. They were counted.',
      if (emergencyExits > 0)
        '$emergencyExits emergency exit${emergencyExits == 1 ? '' : 's'}. Each one is on record.',
      if (contests > 0)
        '$contests verdict${contests == 1 ? '' : 's'} contested.',
    ];
    if (rank == Rank.s) {
      lines.add('Rank S. Hold it.');
    } else if (rank != null) {
      final need = DungeonRules.clearedNeeded - clearedInWindow;
      lines.add(
        need <= 0
            ? 'A Gate is due. Enter it.'
            : 'Next Gate: $need more cleared day${need == 1 ? '' : 's'} in the window.',
      );
    }
    return lines;
  }
}
