import '../domain/day.dart';
import '../domain/penalty.dart';
import 'game_service.dart';

/// One notification the OS should deliver at [at], even if the app is closed.
class PlannedNotice {
  const PlannedNotice(this.id, this.at, this.title, this.body);

  /// Stable per kind, so re-planning replaces rather than duplicates.
  final int id;
  final DateTime at;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotice &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, at, title, body);

  @override
  String toString() => 'PlannedNotice($id, $at, $title)';
}

/// Notification ids, one per kind.
abstract final class NoticeId {
  static const warning3h = 1;
  static const warning1h = 2;
  static const morning = 3;
  static const lockEngaged = 4;
  static const exercise = 5;
}

/// Works out which notifications should be scheduled right now. Pure, so the
/// rules can be tested without a phone.
class NotificationPlanner {
  const NotificationPlanner({
    this.warnAt3h = 21 * 60,
    this.warnAt1h = 23 * 60,
    this.exerciseAt = 20 * 60,
  });

  /// Minutes after midnight for each reminder.
  final int warnAt3h;
  final int warnAt1h;
  final int exerciseAt;

  List<PlannedNotice> plan(GameService g, DateTime now) {
    final today = DayKey.fromDateTime(now);
    final out = <PlannedNotice>[];
    void add(int id, DateTime at, String title, String body) {
      if (at.isAfter(now)) out.add(PlannedNotice(id, at, title, body));
    }

    final incomplete = [
      for (final t in g.todaysTasks)
        if (!t.isComplete(g.liveProgress(t.id))) t,
    ];
    final questOpen = g.state.isOpen(today);

    // Deadline warnings, only while objectives remain.
    if (questOpen && incomplete.isNotEmpty) {
      final names = incomplete.map((t) => t.name).join(', ');
      add(
        NoticeId.warning3h,
        today.at(warnAt3h),
        '[ SYSTEM ] 3 hours remain',
        'Incomplete: $names. Failure will result in a penalty.',
      );
      add(
        NoticeId.warning1h,
        today.at(warnAt1h),
        '[ WARNING ] 1 hour remains',
        'Incomplete: $names. The Penalty Zone follows at midnight.',
      );
    }

    // Tomorrow morning, at the end of the sleep window.
    final wake = _nextWake(g.game.sleep, now);
    // "Judgement pending" only makes sense once today has ended; a wake-up
    // later today is just the start of today's quest.
    final failing =
        questOpen &&
        incomplete.isNotEmpty &&
        DayKey.fromDateTime(wake).isAfter(today);
    add(
      NoticeId.morning,
      wake,
      failing
          ? '[ SYSTEM ] Judgement pending'
          : '[ SYSTEM ] Daily quest issued',
      failing
          ? "Yesterday's quest was left incomplete. Open Do or Die to receive the verdict."
          : 'A new daily quest has arrived. Complete it before midnight.',
    );

    // Exercise owed today.
    final debt = g.state.debt;
    if (debt != null && debt.dueDay == today && !debt.isPaid) {
      final owed = [
        if (debt.pushupsRemaining > 0) '${debt.pushupsRemaining} push-ups',
        if (debt.squatsRemaining > 0) '${debt.squatsRemaining} squats',
      ].join(' and ');
      add(
        NoticeId.exercise,
        today.at(exerciseAt),
        '[ PENALTY ] Exercise owed',
        '$owed remaining. Unpaid reps double at midnight.',
      );
    }

    // The moment a scheduled lock begins; never earlier.
    final lock = g.state.lock;
    if (lock != null) {
      add(
        NoticeId.lockEngaged,
        lock.start,
        '[ PENALTY ZONE ] Lock engaged',
        'Your chosen apps are locked until ${_hm(lock.end)}.',
      );
    }

    return out;
  }

  /// The next end of the sleep window after [now].
  static DateTime _nextWake(SleepWindow sleep, DateTime now) {
    final today = DayKey.fromDateTime(now);
    final todayWake = today.at(sleep.endMinute);
    return todayWake.isAfter(now)
        ? todayWake
        : today.addDays(1).at(sleep.endMinute);
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
