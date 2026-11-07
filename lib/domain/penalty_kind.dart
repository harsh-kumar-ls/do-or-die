import 'penalty.dart';
import 'systems.dart';

export 'penalty.dart' show PenaltyKind;

/// The penalty each System gives besides the app lock. Fitness owes none:
/// exercise is never used as a punishment (iteration 1). Personality owes
/// reading and a reflection; Focus owes a phone-free block. Games without a
/// System keep their bounded exercise.
PenaltyKind penaltyKindFor(SystemKind? system) => switch (system) {
  SystemKind.fitness => PenaltyKind.none,
  null => PenaltyKind.exercise,
  SystemKind.personality => PenaltyKind.reading,
  SystemKind.focus => PenaltyKind.focus,
};
