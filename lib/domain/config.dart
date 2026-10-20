/// Every tunable number in the game lives here. See PROJECT.md section 2.1.
class GameConfig {
  const GameConfig({
    this.basePushups = 50,
    this.pushupsPerLevel = 5,
    this.pushupCap = 150,
    this.baseSquats = 50,
    this.squatsPerLevel = 5,
    this.baseLockMinutes = 240,
    this.lockMinutesPerLevel = 20,
    this.carryOverMultiplier = 2,
    this.xpPerClear = 100,
    this.baseXpToNextLevel = 300,
    this.xpToNextLevelPerLevel = 100,
    this.statPointsPerLevel = 3,
  });

  // Physical penalty, per failed day.
  final int basePushups;
  final int pushupsPerLevel;
  final int pushupCap;

  /// Squats start once push-ups would exceed the cap.
  final int baseSquats;
  final int squatsPerLevel;

  // Digital penalty.
  final int baseLockMinutes;
  final int lockMinutesPerLevel;

  /// Unpaid reps are multiplied by this when carried to the next day
  /// (2 = 100% interest).
  final int carryOverMultiplier;

  // Progression. Placeholder values; tune after the first week of the trial.
  final int xpPerClear;
  final int baseXpToNextLevel;
  final int xpToNextLevelPerLevel;
  final int statPointsPerLevel;
}
