import 'dart:math';

import 'config.dart';
import 'day.dart';

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

  int lockMinutesForLevel(int level) =>
      config.baseLockMinutes + config.lockMinutesPerLevel * (level - 1);
}

/// Exercise owed, due by the end of [dueDay].
class ExerciseDebt {
  const ExerciseDebt({
    required this.dueDay,
    required this.pushupsOwed,
    required this.squatsOwed,
    this.pushupsDone = 0,
    this.squatsDone = 0,
  });

  final DayKey dueDay;
  final int pushupsOwed;
  final int squatsOwed;
  final int pushupsDone;
  final int squatsDone;

  int get pushupsRemaining => max(0, pushupsOwed - pushupsDone);
  int get squatsRemaining => max(0, squatsOwed - squatsDone);
  bool get isPaid => pushupsRemaining == 0 && squatsRemaining == 0;

  ExerciseDebt record({int pushups = 0, int squats = 0}) => ExerciseDebt(
    dueDay: dueDay,
    pushupsOwed: pushupsOwed,
    squatsOwed: squatsOwed,
    pushupsDone: min(pushupsOwed, pushupsDone + max(0, pushups)),
    squatsDone: min(squatsOwed, squatsDone + max(0, squats)),
  );
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
  });

  final DayKey day;
  final DateTime start;
  final DateTime end;

  /// True if the lock was shortened to fit inside waking hours.
  final bool clamped;

  bool isActiveAt(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  Duration get duration => end.difference(start);
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
