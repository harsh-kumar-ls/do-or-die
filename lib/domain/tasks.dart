import 'day.dart';

enum TaskType {
  /// Done or not done. Target is 1.
  checkbox,

  /// Accumulated minutes. Target is in minutes.
  timer,

  /// A count, such as pages read. Target is the count.
  counter,
}

class TaskDefinition {
  const TaskDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.target,
  }) : assert(target > 0);

  final String id;
  final String name;
  final TaskType type;

  /// Minutes for timers; otherwise the count to reach.
  final int target;

  /// What progress is measured against. Timer progress is stored in seconds
  /// so pausing never loses time.
  int get goal => type == TaskType.timer ? target * 60 : target;

  bool isComplete(int progress) => progress >= goal;
}

/// Progress for one day, keyed by task id.
typedef DayProgress = Map<String, int>;

/// One version of the user's task list, in force from [effectiveFrom].
class PlanVersion {
  const PlanVersion(this.effectiveFrom, this.tasks);

  final DayKey effectiveFrom;
  final List<TaskDefinition> tasks;
}

/// The user's task list over time. Edits never change a day that has already
/// started: they take effect from the next day.
class QuestPlan {
  QuestPlan.initial(DayKey startDay, List<TaskDefinition> tasks)
    : versions = List.unmodifiable([PlanVersion(startDay, tasks)]);

  const QuestPlan._(this.versions);

  /// Rebuilds a plan from saved versions.
  QuestPlan.fromVersions(List<PlanVersion> versions)
    : versions = List.unmodifiable(
        [...versions]
          ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom)),
      );

  final List<PlanVersion> versions;

  List<TaskDefinition> tasksFor(DayKey day) {
    PlanVersion? current;
    for (final v in versions) {
      if (!v.effectiveFrom.isAfter(day)) current = v;
    }
    return current?.tasks ?? const [];
  }

  /// Returns a plan where [tasks] apply from the day after [today].
  QuestPlan edit(DayKey today, List<TaskDefinition> tasks) {
    final from = today.addDays(1);
    final kept = versions.where((v) => v.effectiveFrom.isBefore(from));
    return QuestPlan._(List.unmodifiable([...kept, PlanVersion(from, tasks)]));
  }
}
