import '../domain/clock.dart';
import '../domain/day.dart';
import '../platform/blocker.dart';
import 'game_service.dart';

/// Pushes what the rules engine decided to the platform blocker: today's
/// chosen apps, the scheduled lock window, and the first unjudged day.
///
/// Only sends a value when it differs from the last one sent.
class PenaltyEnforcer {
  PenaltyEnforcer(this.blocker, {this.clock = const SystemClock()});

  final AppBlocker blocker;
  final Clock clock;

  Set<String>? _sentPackages;
  (DateTime, DateTime, DateTime?, int, LockMode)? _sentWindow;
  (DateTime, DateTime)? _sentFocus;
  bool _sentNoFocus = false;
  bool _sentNoWindow = false;
  String? _sentJudgeDue;
  String? _sentQuestDone;
  bool _sentQuestDoneOnce = false;

  /// Forgets what was sent, so the next [sync] pushes everything again (after
  /// a reset, or anything else that changed the phone's state behind it).
  void invalidate() {
    _sentPackages = null;
    _sentWindow = null;
    _sentFocus = null;
    _sentNoFocus = false;
    _sentNoWindow = false;
    _sentJudgeDue = null;
    _sentQuestDone = null;
    _sentQuestDoneOnce = false;
  }

  /// Clears the phone's blocker for good (no game any more).
  Future<void> reset() async {
    invalidate();
    await blocker.reset();
  }

  Future<void> sync(GameService game) async {
    final packages = game.blockedToday;
    if (_sentPackages == null ||
        _sentPackages!.length != packages.length ||
        !_sentPackages!.containsAll(packages)) {
      await blocker.setBlockedPackages(packages);
      _sentPackages = {...packages};
    }

    final lock = game.state.lock;
    if (lock != null &&
        !lock.cancelled &&
        lock.effectiveEnd.isAfter(clock.now())) {
      // The day after a failed Dungeon floor gets its own block screen.
      final mode = game.systems?.dungeonPenaltyDay == lock.day
          ? LockMode.dungeon
          : LockMode.penalty;
      final window = (
        lock.start,
        lock.effectiveEnd,
        lock.releasedUntil,
        lock.releases,
        mode,
      );
      if (_sentWindow != window) {
        await blocker.setLockWindow(
          lock.start,
          lock.effectiveEnd,
          releasedUntil: lock.releasedUntil,
          releases: lock.releases,
          mode: mode,
        );
        _sentWindow = window;
        _sentNoWindow = false;
      }
    } else if (!_sentNoWindow) {
      await blocker.clearLockWindow();
      _sentNoWindow = true;
      _sentWindow = null;
    }

    // A running phone-free block locks the chosen apps until it is paused
    // (at most until midnight, when the timer is credited and stopped).
    final block = game.focusBlock;
    if (block != null) {
      final day = DayKey.fromDateTime(block.startedAt);
      var end = day.addDays(1).at(0);
      final deadline = game.systems?.deadlineOn(day);
      if (deadline != null && deadline.isBefore(end)) end = deadline;
      final focus = (block.startedAt, end);
      if (_sentFocus != focus) {
        await blocker.setFocusWindow(focus.$1, focus.$2);
        _sentFocus = focus;
        _sentNoFocus = false;
      }
    } else if (!_sentNoFocus) {
      await blocker.setFocusWindow(null, null);
      _sentNoFocus = true;
      _sentFocus = null;
    }

    final due = game.state.nextDayToClose.toString();
    if (_sentJudgeDue != due) {
      await blocker.setJudgeDueFrom(due);
      _sentJudgeDue = due;
    }

    // A day already cleared, with nothing measured that could still fail
    // it, needs no watcher or redirect after midnight.
    final done = game.questSettled ? game.today.toString() : null;
    if (!_sentQuestDoneOnce || _sentQuestDone != done) {
      await blocker.setQuestDoneFor(done);
      _sentQuestDone = done;
      _sentQuestDoneOnce = true;
    }
  }
}
