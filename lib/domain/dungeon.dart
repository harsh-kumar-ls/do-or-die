import 'dart:math';

import 'day.dart';
import 'progression.dart';
import 'systems.dart';

/// Rules for ranking up: Gates open after 21 of the last 30 days are
/// cleared; a Dungeon is three floors on consecutive days, the third being
/// the Rank Trial. See SYSTEMS_PRD.md sections 4, 5.3 and 6.2.
abstract final class DungeonRules {
  /// Cleared days needed in the window to open a Gate.
  static const clearedNeeded = 21;

  /// The window, in days.
  static const window = 30;

  /// How long an open Gate waits to be entered.
  static const gateLifetime = Duration(hours: 48);

  /// Days before an unentered Gate can open again.
  static const reopenAfterExpiry = 3;

  /// Days the Gate stays shut after a failed Dungeon.
  static const failCooldown = 7;

  /// Floor 2 must be cleared before this time (minutes after midnight).
  static const floor2Deadline = 18 * 60;

  /// How much harder floors 1 and 2 are than the daily quest.
  static const floorBoost = {1: 25, 2: 50};

  /// Stat points for clearing a Dungeon.
  static const clearStatPoints = 5;

  /// Penalty multiplier for a failed Dungeon floor (double lock, double reps).
  static const failMultiplier = 2;
}

class Gate {
  const Gate(this.from, this.openedAt);
  final Rank from;
  final DateTime openedAt;
  DateTime get expiresAt => openedAt.add(DungeonRules.gateLifetime);
}

class Dungeon {
  const Dungeon(this.from, this.firstFloor);

  /// The rank this Dungeon promotes from.
  final Rank from;

  /// The day of floor 1; floors 2 and 3 follow on the next two days.
  final DayKey firstFloor;

  DayKey get bossDay => firstFloor.addDays(2);

  /// 1, 2 or 3 on a floor day; 0 otherwise.
  int floorOn(DayKey day) {
    final n = firstFloor.daysUntil(day);
    return n >= 0 && n <= 2 ? n + 1 : 0;
  }
}

/// Something that happened in a System, for notices and the trial log.
sealed class SystemEvent {
  const SystemEvent(this.day);
  final DayKey day;
}

class GateOpened extends SystemEvent {
  const GateOpened(super.day, this.gate);
  final Gate gate;
}

class GateExpired extends SystemEvent {
  const GateExpired(super.day);
}

class DungeonEntered extends SystemEvent {
  const DungeonEntered(super.day, this.dungeon);
  final Dungeon dungeon;
}

class FloorCleared extends SystemEvent {
  const FloorCleared(super.day, this.floor);
  final int floor;
}

class DungeonCleared extends SystemEvent {
  const DungeonCleared(super.day, this.newRank, this.title);
  final Rank newRank;
  final String title;
}

class DungeonFailed extends SystemEvent {
  const DungeonFailed(super.day, this.floor);
  final int floor;
}

class SystemCompleted extends SystemEvent {
  const SystemCompleted(super.day, this.system);
  final SystemKind system;
}

/// Everything about the user's Systems that changes over time.
class SystemsState {
  const SystemsState({
    required this.progress,
    this.history = const {},
    this.countFrom,
    this.gate,
    this.dungeon,
    this.gateBlockedUntil,
    this.dungeonPenaltyDay,
    this.titles = const [],
    this.sHold = 0,
    this.systemStartedOn,
  });

  final SystemProgress progress;

  /// Judged days in the active System that count toward a Gate: true when
  /// cleared. Dry-run days and Dungeon days are never recorded here.
  final Map<DayKey, bool> history;

  /// Days before this don't count (System start, or the day after a rank-up).
  final DayKey? countFrom;

  final Gate? gate;
  final Dungeon? dungeon;

  /// No Gate may open before this day (after a failure or an expiry).
  final DayKey? gateBlockedUntil;

  /// The day a Dungeon Penalty applies (the day after a failed floor).
  final DayKey? dungeonPenaltyDay;

  final List<String> titles;

  /// Consecutive cleared days at S rank.
  final int sHold;

  final DayKey? systemStartedOn;

  SystemKind? get active => progress.active;
  Rank? get rank => active == null ? null : progress.rankOf(active!);

  SystemsState copyWith({
    SystemProgress? progress,
    Map<DayKey, bool>? history,
    DayKey? Function()? countFrom,
    Gate? Function()? gate,
    Dungeon? Function()? dungeon,
    DayKey? Function()? gateBlockedUntil,
    DayKey? Function()? dungeonPenaltyDay,
    List<String>? titles,
    int? sHold,
    DayKey? Function()? systemStartedOn,
  }) => SystemsState(
    progress: progress ?? this.progress,
    history: history ?? this.history,
    countFrom: countFrom != null ? countFrom() : this.countFrom,
    gate: gate != null ? gate() : this.gate,
    dungeon: dungeon != null ? dungeon() : this.dungeon,
    gateBlockedUntil: gateBlockedUntil != null
        ? gateBlockedUntil()
        : this.gateBlockedUntil,
    dungeonPenaltyDay: dungeonPenaltyDay != null
        ? dungeonPenaltyDay()
        : this.dungeonPenaltyDay,
    titles: titles ?? this.titles,
    sHold: sHold ?? this.sHold,
    systemStartedOn: systemStartedOn != null
        ? systemStartedOn()
        : this.systemStartedOn,
  );

  /// Starts a System at its placement rank.
  SystemsState choose(SystemKind kind, Rank placement, DayKey today) =>
      SystemsState(
        progress: progress.choose(kind, placement),
        countFrom: today,
        titles: titles,
        systemStartedOn: today,
      );

  /// Cleared days in the window ending on [day].
  int clearedInWindow(DayKey day) {
    final earliest = day.addDays(-(DungeonRules.window - 1));
    final from = countFrom != null && countFrom!.isAfter(earliest)
        ? countFrom!
        : earliest;
    var n = 0;
    history.forEach((d, cleared) {
      if (cleared && !d.isBefore(from) && !d.isAfter(day)) n++;
    });
    return n;
  }

  /// The floor (1-3) on [day], or 0.
  int floorOn(DayKey day) => dungeon?.floorOn(day) ?? 0;

  /// Whether a failure on [day] brings the Dungeon Penalty instead of the
  /// normal one.
  bool isDungeonDay(DayKey day) => floorOn(day) > 0;

  /// Floor 2's 18:00 deadline on [day], or null.
  DateTime? deadlineOn(DayKey day) =>
      floorOn(day) == 2 ? day.at(DungeonRules.floor2Deadline) : null;

  /// The quest the System issues for [day]: a floor of the Dungeon, or the
  /// daily quest for the active System and rank.
  ///
  /// No quest before the System starts (a System chosen today starts
  /// tomorrow). Floors are built on the full daily quest: the reduction valve
  /// never applies inside a Dungeon.
  List<QuestItem> questFor(Map<SystemKind, SystemSpec> catalogue, DayKey day) {
    final start = systemStartedOn;
    if (start != null && day.isBefore(start)) return const [];
    final floor = floorOn(day);
    if (floor == 0) return progress.dailyQuest(catalogue, day);
    final spec = catalogue[active!]!.at(dungeon!.from);
    if (floor == 3) return spec.trial.items;
    final boost = DungeonRules.floorBoost[floor]!;
    return [for (final q in spec.daily) q.scaledUpBy(boost)];
  }

  /// Closes an open Gate whose 48 hours ran out.
  (SystemsState, List<SystemEvent>) expireGate(DateTime now) {
    final g = gate;
    if (g == null || now.isBefore(g.expiresAt)) return (this, const []);
    final today = DayKey.fromDateTime(now);
    return (
      copyWith(
        gate: () => null,
        gateBlockedUntil: () => today.addDays(DungeonRules.reopenAfterExpiry),
      ),
      [GateExpired(today)],
    );
  }

  /// Enters the open Gate. Floor 1 is the next day. Returns null when no
  /// Gate is open (or it has expired).
  ///
  /// [firstOpenDay] is the first day not yet judged: floor 1 never lands on
  /// a day already judged, even if the clock has been set back.
  (SystemsState, SystemEvent)? enter(DateTime now, {DayKey? firstOpenDay}) {
    final g = gate;
    if (g == null || !now.isBefore(g.expiresAt)) return null;
    var today = DayKey.fromDateTime(now);
    if (firstOpenDay != null && today.isBefore(firstOpenDay)) {
      today = firstOpenDay;
    }
    final d = Dungeon(g.from, today.addDays(1));
    return (
      copyWith(gate: () => null, dungeon: () => d),
      DungeonEntered(today, d),
    );
  }

  /// Applies the verdict for [day] to the System.
  ///
  /// [dryRun]: the day was a dry run (never counts toward a Gate).
  (SystemsState, List<SystemEvent>) afterDayClosed({
    required DayKey day,
    required bool cleared,
    required bool dryRun,
    required DateTime now,
  }) {
    final kind = active;
    if (kind == null || progress.completed.contains(kind)) {
      return (this, const []);
    }

    // A Dungeon floor.
    final floor = floorOn(day);
    if (floor > 0) {
      if (!cleared) {
        return (
          copyWith(
            dungeon: () => null,
            dungeonPenaltyDay: () => day.addDays(1),
            gateBlockedUntil: () => day.addDays(1 + DungeonRules.failCooldown),
          ),
          [DungeonFailed(day, floor)],
        );
      }
      if (floor < 3) return (this, [FloorCleared(day, floor)]);
      final next = progress.rankUp();
      final newRank = next.rankOf(kind)!;
      final title =
          'Gatebreaker · ${_systemShort(kind)} ${newRank.name.toUpperCase()}';
      return (
        copyWith(
          progress: next,
          dungeon: () => null,
          countFrom: () => day.addDays(1),
          titles: [...titles, title],
        ),
        [DungeonCleared(day, newRank, title)],
      );
    }

    if (dryRun) return (this, const []);

    var s = copyWith(history: {...history, day: cleared});

    // S rank: no Dungeon; hold it.
    if (rank == Rank.s) {
      final hold = cleared ? sHold + 1 : 0;
      s = s.copyWith(sHold: hold);
      final needed = catalogueHoldDays;
      if (hold >= needed) {
        return (
          s.copyWith(progress: progress.rankUp(), sHold: 0),
          [SystemCompleted(day, kind)],
        );
      }
      return (s, const []);
    }

    // Open a Gate?
    final blocked =
        gateBlockedUntil != null && day.addDays(1).isBefore(gateBlockedUntil!);
    if (gate == null &&
        dungeon == null &&
        !blocked &&
        s.clearedInWindow(day) >= DungeonRules.clearedNeeded) {
      final g = Gate(rank!, now);
      return (s.copyWith(gate: () => g), [GateOpened(day, g)]);
    }
    return (s, const []);
  }

  /// Consecutive cleared days needed to complete a System at S.
  static const catalogueHoldDays = 30;

  static String _systemShort(SystemKind k) => switch (k) {
    SystemKind.fitness => 'Fitness',
    SystemKind.personality => 'Personality',
    SystemKind.focus => 'Focus',
  };
}

/// Days remaining until [until], never negative.
int daysLeft(DayKey today, DayKey until) => max(0, today.daysUntil(until));
