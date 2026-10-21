import '../domain/clock.dart';
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
  (DateTime, DateTime, DateTime?, int)? _sentWindow;
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
      final window = (lock.start, lock.end, lock.releasedUntil, lock.releases);
      if (_sentWindow != window) {
        await blocker.setLockWindow(
          lock.start,
          lock.end,
          releasedUntil: lock.releasedUntil,
          releases: lock.releases,
        );
        _sentWindow = window;
        _sentNoWindow = false;
      }
    } else if (!_sentNoWindow) {
      await blocker.clearLockWindow();
      _sentNoWindow = true;
      _sentWindow = null;
    }

    final due = game.state.nextDayToClose.toString();
    if (_sentJudgeDue != due) {
      await blocker.setJudgeDueFrom(due);
      _sentJudgeDue = due;
    }
  }
}
