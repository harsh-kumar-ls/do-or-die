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
