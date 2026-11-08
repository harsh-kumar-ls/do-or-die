/// Every tunable number in the game lives here. See PROJECT.md section 2.1.
class GameConfig {
  const GameConfig({
    this.defaultPushups = 10,
    this.defaultSquats = 15,
    this.basePages = 20,
    this.pagesPerLevel = 2,
    this.pagesCap = 60,
    this.reflections = 1,
    this.baseBlockMinutes = 60,
    this.blockMinutesPerLevel = 5,
    this.blockMinutesCap = 180,
    this.baseLockMinutes = 240,
    this.lockMinutesPerLevel = 0,
    this.releasesPerLock = 2,
    this.contestCooldownDays = 14,
    this.blockRemovalDelayDays = 7,
    this.nearMissPercent = 80,
    this.minWakingMinutes = 12 * 60,
    this.xpPerClear = 100,
    this.baseXpToNextLevel = 300,
    this.xpToNextLevelPerLevel = 100,
    this.statPointsPerLevel = 3,
  });

  // Physical penalty, per failed day. Safety rule (audit 2026-11-07): it is
  // never more than the push-ups and squats in the user's own daily quest,
  // never scales with level, never doubles and never carries over. These
  // defaults (the rank E Fitness quest) apply only when no quest volume is
  // given, for games without a System.
  final int defaultPushups;
  final int defaultSquats;

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

  // Digital penalty (every System). The lock is a fixed length at a time
  // the user chose (iteration 1): it no longer grows with level, so long-term
  // success is never punished harder.
  final int baseLockMinutes;
  final int lockMinutesPerLevel;

  /// Short releases allowed per lock. The emergency exit is separate and
  /// always available.
  final int releasesPerLock;

  /// One contested verdict is allowed in any this-many days.
  final int contestCooldownDays;

  /// Removing an app from the lock list takes effect after this many days,
  /// so the list can't be emptied to dodge a lock or a screen-time cap.
  final int blockRemovalDelayDays;

  /// A failed day with at least this much of the quest done (averaged over
  /// its items) is a near miss: no penalty and no lock, but no XP and it
  /// doesn't count toward a Gate. Never on a Dungeon floor.
  final int nearMissPercent;

  /// The rest period can't leave fewer waking minutes than this, so a lock
  /// always has room and the rest period can't be stretched to dodge one.
  final int minWakingMinutes;

  // Progression. Placeholder values; tune after the first week of the trial.
  final int xpPerClear;
  final int baseXpToNextLevel;
  final int xpToNextLevelPerLevel;
  final int statPointsPerLevel;
}
