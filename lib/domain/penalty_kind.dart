import 'penalty.dart';
import 'systems.dart';

export 'penalty.dart' show PenaltyKind;

/// The penalty each System gives: Fitness trains the body, so it owes reps;
/// Personality owes reading and a reflection; Focus owes a phone-free block.
/// Games without a System keep exercise.
PenaltyKind penaltyKindFor(SystemKind? system) => switch (system) {
  SystemKind.fitness || null => PenaltyKind.exercise,
  SystemKind.personality => PenaltyKind.reading,
  SystemKind.focus => PenaltyKind.focus,
};

/// The push-ups and squats in [quest], as (push-ups, squats). The Fitness
/// penalty is exactly this, so it is never more than the user already does
/// in a day. A quest with neither (Fitness rank S) owes no exercise.
(int, int) exerciseVolume(List<QuestItem> quest) {
  var pushups = 0;
  var squats = 0;
  for (final q in quest) {
    if (q.id == 'pushups') pushups += q.target;
    if (q.id == 'squats') squats += q.target;
  }
  return (pushups, squats);
}
