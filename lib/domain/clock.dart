/// Source of the current time. Everything in the app reads time through this,
/// so tests can jump to any moment and a trusted time source can be swapped in.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock that only moves when told to. Used by tests and dry-run mode.
class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime t) => _now = t;

  void advance(Duration d) => _now = _now.add(d);
}
