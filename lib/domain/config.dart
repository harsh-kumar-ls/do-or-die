/// Every tunable number in the game lives here. See PROJECT.md section 2.1.
class GameConfig {
  const GameConfig({
    this.basePushups = 50,
    this.pushupsPerLevel = 5,
    this.pushupCap = 150,
    this.baseSquats = 50,
    this.squatsPerLevel = 5,
    this.basePages = 20,
    this.pagesPerLevel = 2,
    this.pagesCap = 60,
    this.reflections = 1,
    this.baseBlockMinutes = 60,
    this.blockMinutesPerLevel = 5,
    this.blockMinutesCap = 180,
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

  // Personality System penalty: pages to read, and a written reflection on
  // why the quest failed.
  final int basePages;
  final int pagesPerLevel;
  final int pagesCap;
  final int reflections;

  // Focus System penalty: a phone-free block, in minutes.
  final int baseBlockMinutes;
  final int blockMinutesPerLevel;
  final int blockMinutesCap;

  // Digital penalty (every System).
  final int baseLockMinutes;
  final int lockMinutesPerLevel;

  /// Anything unpaid (reps, pages, minutes) is multiplied by this when carried to the next day
  /// (2 = 100% interest).
  final int carryOverMultiplier;

  // Progression. Placeholder values; tune after the first week of the trial.
  final int xpPerClear;
  final int baseXpToNextLevel;
  final int xpToNextLevelPerLevel;
  final int statPointsPerLevel;
}
