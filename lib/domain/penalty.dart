import 'dart:math';

import 'config.dart';
import 'day.dart';

/// What a failed day costs besides the app lock. Each System has its own,
/// so the penalty trains what the System trains: a Personality failure is
/// not paid in push-ups.
enum PenaltyKind {
  /// Push-ups, then squats past the cap (Fitness, and games without a System).
  exercise,

  /// Pages to read, plus a written reflection on why the quest failed
  /// (Personality).
  reading,

  /// A phone-free block, in minutes, run with the in-app timer (Focus).
  focus,
}

class PenaltyCalculator {
  const PenaltyCalculator(this.config);

  final GameConfig config;

  int _rawPushups(int level) =>
      config.basePushups + config.pushupsPerLevel * (level - 1);

  int pushupsForLevel(int level) => min(_rawPushups(level), config.pushupCap);

  /// The first level at which push-ups would exceed the cap.
  int get firstSquatLevel =>
      (config.pushupCap - config.basePushups) ~/ config.pushupsPerLevel + 2;

  int squatsForLevel(int level) {
    if (_rawPushups(level) <= config.pushupCap) return 0;
    return config.baseSquats +
        config.squatsPerLevel * (level - firstSquatLevel);
  }

  /// The penalty for failing at [level] as (primary, secondary), scaled by
  /// [multiplier] (2 for a failed Dungeon floor). Push-ups never go above
  /// the cap, even doubled: the excess becomes squats.
  (int, int) amountsFor(PenaltyKind kind, int level, {int multiplier = 1}) {
    switch (kind) {
      case PenaltyKind.exercise:
        final pushups = pushupsForLevel(level) * multiplier;
        final capped = min(pushups, config.pushupCap);
        return (
          capped,
          squatsForLevel(level) * multiplier + (pushups - capped),
        );
      case PenaltyKind.reading:
        final pages = min(
          config.basePages + config.pagesPerLevel * (level - 1),
          config.pagesCap,
        );
        return (pages * multiplier, config.reflections * multiplier);
      case PenaltyKind.focus:
        final minutes = min(
          config.baseBlockMinutes + config.blockMinutesPerLevel * (level - 1),
          config.blockMinutesCap,
        );
        return (minutes * multiplier, 0);
    }
  }

  int lockMinutesForLevel(int level) =>
      config.baseLockMinutes + config.lockMinutesPerLevel * (level - 1);
}

/// A penalty owed, due by the end of [dueDay]. What the two amounts mean
/// depends on [kind]: push-ups and squats, pages and reflections, or
/// phone-free minutes (no secondary).
class PenaltyDebt {
  const PenaltyDebt({
    required this.dueDay,
    required this.primaryOwed,
    required this.secondaryOwed,
    this.primaryDone = 0,
    this.secondaryDone = 0,
    this.kind = PenaltyKind.exercise,
  });

  final DayKey dueDay;
  final PenaltyKind kind;
  final int primaryOwed;
  final int secondaryOwed;
  final int primaryDone;
  final int secondaryDone;

  int get primaryRemaining => max(0, primaryOwed - primaryDone);
  int get secondaryRemaining => max(0, secondaryOwed - secondaryDone);
  bool get isPaid => primaryRemaining == 0 && secondaryRemaining == 0;

  /// Adds work done; a negative amount corrects a mis-tap. Done never goes
  /// below zero or above what is owed.
  PenaltyDebt record({int primary = 0, int secondary = 0}) => PenaltyDebt(
    dueDay: dueDay,
    kind: kind,
    primaryOwed: primaryOwed,
    secondaryOwed: secondaryOwed,
    primaryDone: (primaryDone + primary).clamp(0, primaryOwed),
    secondaryDone: (secondaryDone + secondary).clamp(0, secondaryOwed),
  );
}

/// How a penalty reads to the user, e.g. "40 push-ups and 10 squats".
String describePenalty(PenaltyKind kind, int primary, int secondary) {
  String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final parts = switch (kind) {
    PenaltyKind.exercise => [
      if (primary > 0) plural(primary, 'push-up', 'push-ups'),
      if (secondary > 0) plural(secondary, 'squat', 'squats'),
    ],
    PenaltyKind.reading => [
      if (primary > 0) plural(primary, 'page', 'pages'),
      if (secondary > 0)
        plural(secondary, 'written reflection', 'written reflections'),
    ],
    PenaltyKind.focus => [if (primary > 0) '$primary phone-free minutes'],
  };
  return parts.join(' and ');
}

/// Hours the user is asleep. Crosses midnight when [startMinute] > [endMinute].
class SleepWindow {
  const SleepWindow({this.startMinute = 23 * 60, this.endMinute = 7 * 60})
    : assert(startMinute != endMinute);

  /// Minutes after midnight when sleep starts.
  final int startMinute;

  /// Minutes after midnight when sleep ends.
  final int endMinute;

  /// The waking period that begins on [day]: from wake-up on [day] until the
  /// next time sleep starts.
  (DateTime, DateTime) wakingPeriod(DayKey day) {
    final start = day.at(endMinute);
    final end = startMinute > endMinute
        ? day.at(startMinute)
        : day.addDays(1).at(startMinute);
    return (start, end);
  }
}

class LockWindow {
  const LockWindow({
    required this.day,
    required this.start,
    required this.end,
    this.clamped = false,
    this.releasedUntil,
    this.releases = 0,
  });

  final DayKey day;
  final DateTime start;
  final DateTime end;

  /// True if the lock was shortened to fit inside waking hours.
  final bool clamped;

  /// End of the current short release, if one was taken. The window's own
  /// end never moves: a release spends lock time, it doesn't add any.
  final DateTime? releasedUntil;

  /// How many releases have been taken during this lock.
  final int releases;

  bool inWindowAt(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  bool isReleasedAt(DateTime t) =>
      inWindowAt(t) && releasedUntil != null && t.isBefore(releasedUntil!);

  /// Apps are locked: inside the window and not in a release.
  bool isActiveAt(DateTime t) => inWindowAt(t) && !isReleasedAt(t);

  Duration get duration => end.difference(start);

  /// A copy with one more release, lasting [length] from [now].
  LockWindow releaseAt(DateTime now, Duration length) => LockWindow(
    day: day,
    start: start,
    end: end,
    clamped: clamped,
    releasedUntil: now.add(length),
    releases: releases + 1,
  );
}

class LockScheduler {
  const LockScheduler();

  /// Picks a random lock window on [day] that lies entirely inside waking
  /// hours and starts no earlier than [notBefore]. Returns null if no waking
  /// time is left that day.
  LockWindow? schedule({
    required DayKey day,
    required int durationMinutes,
    required SleepWindow sleep,
    required Random random,
    DateTime? notBefore,
  }) {
    var (wakeStart, wakeEnd) = sleep.wakingPeriod(day);
    if (notBefore != null && notBefore.isAfter(wakeStart)) {
      wakeStart = _ceilToMinute(notBefore);
    }
    final available = wakeEnd.difference(wakeStart).inMinutes;
    if (available <= 0) return null;

    if (durationMinutes >= available) {
      return LockWindow(
        day: day,
        start: wakeStart,
        end: wakeEnd,
        clamped: true,
      );
    }
    final start = wakeStart.add(
      Duration(minutes: random.nextInt(available - durationMinutes + 1)),
    );
    return LockWindow(
      day: day,
      start: start,
      end: start.add(Duration(minutes: durationMinutes)),
    );
  }

  static DateTime _ceilToMinute(DateTime t) {
    final floored = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    return floored == t ? t : floored.add(const Duration(minutes: 1));
  }
}

/// Lines a reflection needs, each of at least [reflectionWordsPerLine]
/// words, so five lines of "a" don't pass.
const reflectionLines = 5;
const reflectionWordsPerLine = 4;

/// Lines of [text] that count toward a reflection.
int reflectionLineCount(String text) => text
    .split('\n')
    .where(
      (l) =>
          l.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >=
          reflectionWordsPerLine,
    )
    .length;

/// A reflection counts when it has [reflectionLines] real lines.
bool reflectionAccepted(String text) =>
    reflectionLineCount(text) >= reflectionLines;
