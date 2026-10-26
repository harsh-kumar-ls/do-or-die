import 'progression.dart';
import 'systems.dart';

/// The placement test: a few questions per System that set the starting
/// rank. It can grant E, D or C only; B and above are earned in Dungeons.
/// See SYSTEMS_PRD.md section 6.3.
class PlacementQuestion {
  const PlacementQuestion(
    this.id,
    this.prompt,
    this.unit, {
    required this.min,
    required this.max,
    required this.initial,
  });

  final String id;
  final String prompt;
  final String unit;
  final int min;
  final int max;
  final int initial;
}

const placementQuestions = <SystemKind, List<PlacementQuestion>>{
  SystemKind.fitness: [
    PlacementQuestion(
      'pushups',
      'Most push-ups you can do in one set',
      'reps',
      min: 0,
      max: 100,
      initial: 10,
    ),
    PlacementQuestion(
      'km_minutes',
      'Minutes to walk or jog 1 km',
      'min',
      min: 3,
      max: 30,
      initial: 12,
    ),
  ],
  SystemKind.personality: [
    PlacementQuestion(
      'pages',
      'Pages read per day, lately',
      'pages',
      min: 0,
      max: 200,
      initial: 5,
    ),
    PlacementQuestion(
      'comfort',
      'Comfort starting a conversation with a stranger (1 to 5)',
      '1-5',
      min: 1,
      max: 5,
      initial: 2,
    ),
  ],
  SystemKind.focus: [
    PlacementQuestion(
      'social_minutes',
      "Yesterday's social-media minutes",
      'min',
      min: 0,
      max: 900,
      initial: 120,
    ),
  ],
};

/// The starting rank for [answers] (keyed by question id). Missing answers
/// count as the question's initial value.
Rank placementFor(SystemKind kind, Map<String, int> answers) {
  int a(String id) =>
      answers[id] ??
      placementQuestions[kind]!.firstWhere((q) => q.id == id).initial;
  final rank = switch (kind) {
    SystemKind.fitness =>
      a('pushups') >= 35 && a('km_minutes') <= 7
          ? Rank.c
          : a('pushups') >= 20 && a('km_minutes') <= 10
          ? Rank.d
          : Rank.e,
    SystemKind.personality =>
      a('pages') >= 30 && a('comfort') >= 4
          ? Rank.c
          : a('pages') >= 15 && a('comfort') >= 3
          ? Rank.d
          : Rank.e,
    SystemKind.focus =>
      a('social_minutes') <= 40
          ? Rank.c
          : a('social_minutes') <= 60
          ? Rank.d
          : Rank.e,
  };
  // Never above the highest placement, whatever the table above says.
  return rank.index > highestPlacement.index ? highestPlacement : rank;
}
