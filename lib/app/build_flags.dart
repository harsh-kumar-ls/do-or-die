/// Build-time switches, set with `--dart-define`.
abstract final class BuildFlags {
  /// A tester build with the Focus System only: Fitness and Personality
  /// are hidden (`--dart-define=DOD_FOCUS_ONLY=true`).
  static const focusOnly = bool.fromEnvironment('DOD_FOCUS_ONLY');
}
