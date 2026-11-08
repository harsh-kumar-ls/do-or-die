/// Build-time switches, set with `--dart-define`.
abstract final class BuildFlags {
  /// The full game: all three Systems, Gates and Dungeons, levels and stat
  /// points (`--dart-define=DOD_FULL=true`). Off by default.
  static const full = bool.fromEnvironment('DOD_FULL');

  /// The default build: the simple game (Focus only, milestones, short
  /// terms, no levels or stat points on screen).
  static const simple = !full;
}
