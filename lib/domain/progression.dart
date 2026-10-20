import 'config.dart';

enum Rank { e, d, c, b, a, s }

enum Stat { strength, intellect, discipline, vitality }

class Progression {
  const Progression(this.config);

  final GameConfig config;

  int xpToNextLevel(int level) =>
      config.baseXpToNextLevel + config.xpToNextLevelPerLevel * (level - 1);

  /// Placeholder thresholds: a new rank every 10 levels, S from level 50.
  Rank rankForLevel(int level) {
    if (level >= 50) return Rank.s;
    if (level >= 40) return Rank.a;
    if (level >= 30) return Rank.b;
    if (level >= 20) return Rank.c;
    if (level >= 10) return Rank.d;
    return Rank.e;
  }
}
