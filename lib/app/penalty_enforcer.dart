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

  Future<void> sync(GameService game) async {
    final packages = game.blockedToday;
    if (_sentPackages == null ||
        _sentPackages!.length != packages.length ||
        !_sentPackages!.containsAll(packages)) {
      await blocker.setBlockedPackages(packages);
      _sentPackages = {...packages};
    }

    final lock = game.state.lock;
    if (lock != null && lock.end.isAfter(clock.now())) {
      // The day after a failed Dungeon floor gets its own block screen.
      final mode = game.systems?.dungeonPenaltyDay == lock.day
          ? LockMode.dungeon
          : LockMode.penalty;
      final window = (
        lock.start,
        lock.end,
        lock.releasedUntil,
        lock.releases,
        mode,
      );
      if (_sentWindow != window) {
        await blocker.setLockWindow(
          lock.start,
          lock.end,
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
      final focus = (block.startedAt, day.addDays(1).at(0));
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
  }
}
