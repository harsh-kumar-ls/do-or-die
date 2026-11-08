import '../domain/block_list.dart';
import '../domain/day.dart';
import '../domain/dungeon.dart';
import '../domain/engine.dart';
import '../domain/penalty.dart';
import '../domain/progression.dart';
import '../domain/systems.dart';
import '../domain/tasks.dart';

/// An instant as UTC ISO-8601 (with "Z"), so a time-zone change can't move
/// it. Reading accepts older saves without an offset (read as local time).
String instantToJson(DateTime t) => t.toUtc().toIso8601String();

/// Reads an instant written by [instantToJson] (or an older local one) and
/// returns it in local time.
DateTime instantFromJson(Object? v) => DateTime.parse(v as String).toLocal();

/// Hand-written JSON conversion for everything that is saved. Kept explicit
/// so a saved file stays readable and stable across app versions.

String dayToJson(DayKey d) => d.toString();

DayKey dayFromJson(Object? j) {
  final parts = (j as String).split('-').map(int.parse).toList();
  return DayKey(parts[0], parts[1], parts[2]);
}

Map<String, Object?> taskToJson(TaskDefinition t) => {
  'id': t.id,
  'name': t.name,
  'type': t.type.name,
  'target': t.target,
};

TaskDefinition taskFromJson(Map<String, Object?> j) => TaskDefinition(
  id: j['id'] as String,
  name: j['name'] as String,
  type: TaskType.values.byName(j['type'] as String),
  target: j['target'] as int,
);

Map<String, Object?> planToJson(QuestPlan p) => {
  'versions': [
    for (final v in p.versions)
      {
        'effectiveFrom': dayToJson(v.effectiveFrom),
        'tasks': [for (final t in v.tasks) taskToJson(t)],
      },
  ],
};

QuestPlan planFromJson(Map<String, Object?> j) {
  final versions = [
    for (final v in (j['versions'] as List).cast<Map<String, Object?>>())
      PlanVersion(dayFromJson(v['effectiveFrom']), [
        for (final t in (v['tasks'] as List).cast<Map<String, Object?>>())
          taskFromJson(t),
      ]),
  ];
  return QuestPlan.fromVersions(versions);
}

Map<String, Object?> blockListToJson(BlockList b) => {
  'versions': [
    for (final v in b.versions)
      {
        'effectiveFrom': dayToJson(v.effectiveFrom),
        'packages': v.packages.toList()..sort(),
      },
  ],
};

BlockList blockListFromJson(Map<String, Object?> j) => BlockList.fromVersions([
  for (final v in (j['versions'] as List).cast<Map<String, Object?>>())
    BlockListVersion(
      dayFromJson(v['effectiveFrom']),
      Set.unmodifiable((v['packages'] as List).cast<String>()),
    ),
]);

Map<String, Object?> sleepToJson(SleepWindow s) => {
  'startMinute': s.startMinute,
  'endMinute': s.endMinute,
};

SleepWindow sleepFromJson(Map<String, Object?> j) => SleepWindow(
  startMinute: j['startMinute'] as int,
  endMinute: j['endMinute'] as int,
);

Map<String, Object?>? debtToJson(PenaltyDebt? d) => d == null
    ? null
    : {
        'dueDay': dayToJson(d.dueDay),
        'kind': d.kind.name,
        'primaryOwed': d.primaryOwed,
        'secondaryOwed': d.secondaryOwed,
        'primaryDone': d.primaryDone,
        'secondaryDone': d.secondaryDone,
      };

/// Reads a debt. Saves from before penalty kinds used push-up and squat
/// key names, and were always exercise.
PenaltyDebt? debtFromJson(Map<String, Object?>? j) {
  if (j == null) return null;
  int n(String key, String legacy) => (j[key] ?? j[legacy] ?? 0) as int;
  final kind = j['kind'] as String?;
  return PenaltyDebt(
    dueDay: dayFromJson(j['dueDay']),
    kind: kind == null ? PenaltyKind.exercise : PenaltyKind.values.byName(kind),
    primaryOwed: n('primaryOwed', 'pushupsOwed'),
    secondaryOwed: n('secondaryOwed', 'squatsOwed'),
    primaryDone: n('primaryDone', 'pushupsDone'),
    secondaryDone: n('secondaryDone', 'squatsDone'),
  );
}

Map<String, Object?>? lockToJson(LockWindow? w) => w == null
    ? null
    : {
        'day': dayToJson(w.day),
        'start': instantToJson(w.start),
        'end': instantToJson(w.end),
        'clamped': w.clamped,
        'releasedUntil': w.releasedUntil == null
            ? null
            : instantToJson(w.releasedUntil!),
        'releases': w.releases,
        'exitedAt': w.exitedAt == null ? null : instantToJson(w.exitedAt!),
      };

LockWindow? lockFromJson(Map<String, Object?>? j) => j == null
    ? null
    : LockWindow(
        day: dayFromJson(j['day']),
        start: instantFromJson(j['start']),
        end: instantFromJson(j['end']),
        clamped: j['clamped'] as bool,
        // Absent in saves made before releases existed.
        releasedUntil: j['releasedUntil'] == null
            ? null
            : instantFromJson(j['releasedUntil']),
        releases: (j['releases'] as int?) ?? 0,
        exitedAt: j['exitedAt'] == null ? null : instantFromJson(j['exitedAt']),
      );

Map<String, Object?> stateToJson(GameState s) => {
  'startDay': dayToJson(s.startDay),
  'lastClosedDay': s.lastClosedDay == null ? null : dayToJson(s.lastClosedDay!),
  'level': s.level,
  'xp': s.xp,
  'unspentStatPoints': s.unspentStatPoints,
  'stats': {for (final e in s.stats.entries) e.key.name: e.value},
  'debt': debtToJson(s.debt),
  'lock': lockToJson(s.lock),
};

GameState stateFromJson(Map<String, Object?> j) => GameState(
  startDay: dayFromJson(j['startDay']),
  lastClosedDay: j['lastClosedDay'] == null
      ? null
      : dayFromJson(j['lastClosedDay']),
  level: j['level'] as int,
  xp: j['xp'] as int,
  unspentStatPoints: j['unspentStatPoints'] as int,
  stats: {
    for (final e in (j['stats'] as Map).cast<String, int>().entries)
      Stat.values.byName(e.key): e.value,
  },
  debt: debtFromJson((j['debt'] as Map?)?.cast<String, Object?>()),
  lock: lockFromJson((j['lock'] as Map?)?.cast<String, Object?>()),
);

Map<String, Object?> progressToJson(Map<DayKey, DayProgress> p) => {
  for (final e in p.entries) dayToJson(e.key): e.value,
};

Map<DayKey, DayProgress> progressFromJson(Map<String, Object?> j) => {
  for (final e in j.entries)
    dayFromJson(e.key): Map<String, int>.from(e.value as Map),
};

// ---- Systems & Dungeons -------------------------------------------------

Map<String, Object?> questItemToJson(QuestItem q) => {
  'id': q.id,
  'label': q.label,
  'kind': q.kind.name,
  'target': q.target,
};

Map<String, Object?> systemsToJson(SystemsState s) => {
  'active': s.progress.active?.name,
  'ranks': {for (final e in s.progress.ranks.entries) e.key.name: e.value.name},
  'completed': [for (final k in s.progress.completed) k.name],
  'reductions': [
    for (final (from, pct) in s.progress.reductions)
      {'from': dayToJson(from), 'percent': pct},
  ],
  'history': {for (final e in s.history.entries) dayToJson(e.key): e.value},
  'countFrom': s.countFrom == null ? null : dayToJson(s.countFrom!),
  'gate': s.gate == null
      ? null
      : {
          'from': s.gate!.from.name,
          'openedAt': instantToJson(s.gate!.openedAt),
        },
  'dungeon': s.dungeon == null
      ? null
      : {
          'from': s.dungeon!.from.name,
          'firstFloor': dayToJson(s.dungeon!.firstFloor),
        },
  'gateBlockedUntil': s.gateBlockedUntil == null
      ? null
      : dayToJson(s.gateBlockedUntil!),
  'dungeonPenaltyDay': s.dungeonPenaltyDay == null
      ? null
      : dayToJson(s.dungeonPenaltyDay!),
  'titles': s.titles,
  'sHold': s.sHold,
  'systemStartedOn': s.systemStartedOn == null
      ? null
      : dayToJson(s.systemStartedOn!),
  'previous': s.previous?.name,
  'issued': {
    for (final e in s.issued.entries)
      dayToJson(e.key): [for (final q in e.value) questItemToJson(q)],
  },
};

QuestItem questItemFromJson(Map<String, Object?> j) => QuestItem(
  j['id'] as String,
  j['label'] as String,
  QuestKind.values.byName(j['kind'] as String),
  j['target'] as int,
);

SystemsState systemsFromJson(Map<String, Object?> j) {
  DayKey? day(String k) => j[k] == null ? null : dayFromJson(j[k]);
  final active = j['active'] as String?;
  final gate = (j['gate'] as Map?)?.cast<String, Object?>();
  final dungeon = (j['dungeon'] as Map?)?.cast<String, Object?>();
  return SystemsState(
    progress: SystemProgress(
      active: active == null ? null : SystemKind.values.byName(active),
      ranks: {
        for (final e in (j['ranks'] as Map).cast<String, String>().entries)
          SystemKind.values.byName(e.key): Rank.values.byName(e.value),
      },
      completed: {
        for (final k in (j['completed'] as List).cast<String>())
          SystemKind.values.byName(k),
      },
      reductions: [
        for (final r in (j['reductions'] as List).cast<Map>())
          (dayFromJson(r['from']), r['percent'] as int),
      ],
    ),
    history: {
      for (final e in (j['history'] as Map).cast<String, bool>().entries)
        dayFromJson(e.key): e.value,
    },
    countFrom: day('countFrom'),
    gate: gate == null
        ? null
        : Gate(
            Rank.values.byName(gate['from'] as String),
            instantFromJson(gate['openedAt']),
          ),
    dungeon: dungeon == null
        ? null
        : Dungeon(
            Rank.values.byName(dungeon['from'] as String),
            dayFromJson(dungeon['firstFloor']),
          ),
    gateBlockedUntil: day('gateBlockedUntil'),
    dungeonPenaltyDay: day('dungeonPenaltyDay'),
    titles: (j['titles'] as List).cast<String>(),
    sHold: j['sHold'] as int,
    systemStartedOn: day('systemStartedOn'),
    previous: j['previous'] == null
        ? null
        : SystemKind.values.byName(j['previous'] as String),
    issued: {
      for (final e in ((j['issued'] as Map?) ?? const {}).entries)
        dayFromJson(e.key): [
          for (final q in (e.value as List).cast<Map>())
            questItemFromJson(q.cast<String, Object?>()),
        ],
    },
  );
}

/// A System quest item as an engine task.
TaskDefinition questTask(QuestItem q) => TaskDefinition(
  id: q.id,
  name: q.label,
  type: switch (q.kind) {
    QuestKind.checkbox => TaskType.checkbox,
    QuestKind.timer => TaskType.timer,
    QuestKind.counter => TaskType.counter,
    QuestKind.distance => TaskType.distance,
    QuestKind.screenCap => TaskType.screenCap,
    QuestKind.phoneFree => TaskType.phoneFree,
  },
  // A 0-minute cap (a full fast) is a valid target; TaskDefinition requires
  // a positive target only for goals.
  target: q.target,
);
