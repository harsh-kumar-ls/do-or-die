import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/progression.dart';
import '../../domain/tasks.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_kit.dart';
import '../widgets/system_frame.dart';

/// The Daily Quest, built from design/claude-design/daily-quest.html. On a
/// Dungeon floor the whole tab takes the crimson and gold look.
class QuestScreen extends StatelessWidget {
  const QuestScreen({
    super.key,
    required this.model,
    required this.onOpenPenalty,
  });

  final GameModel model;
  final VoidCallback onOpenPenalty;

  /// "DAY 12 / 30 · FITNESS", "DUNGEON DAY 2 / 3 · FITNESS".
  static String kicker(GameModel m) {
    final sys = m.systemSpec?.name.split(' ').first.toUpperCase();
    final floor = m.floorToday;
    final day = m.service.trialDay;
    final head = floor > 0
        ? 'DUNGEON DAY $floor / 3'
        : day <= 30
        ? 'DAY $day / 30'
        : 'DAY $day';
    final dry = m.service.isDryRunToday ? ' · DRY RUN' : '';
    return sys == null ? '$head$dry' : '$head$dry · $sys';
  }

  @override
  Widget build(BuildContext context) {
    final floor = model.floorToday;
    final screen = Ticker1s(
      builder: (context) {
        model.checkCompletion();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SysTopBar(
                now: model.now,
                kicker: kicker(model),
                rank: model.rank,
              ),
              ..._alerts(context),
              if (model.gate != null && floor == 0) ...[
                _GateBanner(model: model),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: model.tasks.isEmpty && model.canChooseSystem
                    ? HudFrame(
                        title: '[ SYSTEM COMPLETE ]',
                        child: Text(
                          'No quest is issued until the next System is chosen. Choose it on the Status tab.',
                          textAlign: TextAlign.center,
                          style: Hud.mono(
                            13,
                            HudScope.of(context).text,
                          ).copyWith(height: 1.5),
                        ),
                      )
                    : _QuestWindow(model: model),
              ),
            ],
          ),
        );
      },
    );
    // Dungeon floors: crimson lines, gold titles.
    if (floor == 0) return screen;
    return HudScope(palette: HudPalette.dungeon, child: screen);
  }

  List<Widget> _alerts(BuildContext context) {
    final items = <Widget>[];
    void add(String title, String body, String action, VoidCallback onTap) {
      items
        ..add(_Alert(title: title, body: body, action: action, onTap: onTap))
        ..add(const SizedBox(height: 8));
    }

    if (model.inPenalty) {
      add(
        model.dungeonPenalty ? 'DUNGEON PENALTY ACTIVE' : 'PENALTY ZONE ACTIVE',
        'A penalty is in effect today.',
        'OPEN',
        onOpenPenalty,
      );
    }
    if (model.blockerOffline) {
      add('BLOCKER OFFLINE', 'Locks cannot be enforced.', 'FIX', onOpenPenalty);
    }
    if (model.manualClock) {
      add(
        'MANUAL CLOCK',
        "The phone's clock can't be trusted.",
        'FIX',
        model.openDateSettings,
      );
    }
    if (model.notificationsBlocked) {
      add(
        'NOTICES BLOCKED',
        'Warnings cannot reach you.',
        'ALLOW',
        model.requestNotifications,
      );
    } else if (model.lateNotices) {
      add(
        'LATE NOTICES',
        'Allow "Alarms & reminders" for on-time alerts.',
        'ALLOW',
        model.requestExactTiming,
      );
    }
    return items;
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Semantics(
      button: true,
      label: '$title. $body $action',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Hud.warn.withValues(alpha: .06),
            border: Border.all(color: Hud.warn.withValues(alpha: .45)),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Hud.head(11, Hud.warn, spacing: .2)),
                      const SizedBox(height: 2),
                      Text(body, style: Hud.mono(11, p.text)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('$action ›', style: Hud.mono(11, p.hi)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gate banner

class _GateBanner extends StatelessWidget {
  const _GateBanner({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final gate = model.gate!;
    final left = gate.expiresAt.difference(model.now);
    final next = Rank.values[min(gate.from.index + 1, Rank.s.index)];
    return ClipPath(
      clipper: const ChamferClipper(10, corners: [true, false, true, false]),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Hud.gold, Color(0x40F5C96A), Color(0xFFB07CFF)],
          ),
        ),
        child: ClipPath(
          clipper: const ChamferClipper(9, corners: [true, false, true, false]),
          child: Container(
            color: const Color(0xFF100E20),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const CustomPaint(
                      size: Size(46, 56),
                      painter: _PortalPainter(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '[ GATE OPEN ]',
                            style: Hud.head(13, Hud.gold, spacing: .22),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '21 of 30 days cleared. Rank Trial ${gate.from.name.toUpperCase()} → ${next.name.toUpperCase()}.',
                            style: Hud.mono(11, const Color(0xFFDBE7FF)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            left.isNegative
                                ? 'CLOSING'
                                : 'CLOSES IN ${hms(left)}',
                            style: Hud.mono(
                              11,
                              Hud.rankColor(Rank.b),
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                HudScope(
                  palette: const HudPalette(
                    sys: Hud.gold,
                    hi: Hud.gold,
                    voidColor: Color(0xFF05070D),
                    top: Color(0xFF17140C),
                    panel: Color(0xB817140C),
                    text: Color(0xFFDBE7FF),
                    dim: Color(0xFF7D8BA8),
                    glow: 10,
                    glowAlpha: .5,
                    gridAlpha: 0,
                    scanAlpha: 0,
                    lineAlpha: .5,
                  ),
                  child: ChargeButton(
                    label: 'HOLD TO ENTER',
                    holdFor: const Duration(milliseconds: 1500),
                    onConfirmed: model.enterGate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalPainter extends CustomPainter {
  const _PortalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = Hud.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(
      Path()
        ..moveTo(23, 2)
        ..lineTo(44, 14)
        ..lineTo(44, 42)
        ..lineTo(23, 54)
        ..lineTo(2, 42)
        ..lineTo(2, 14)
        ..close(),
      gold,
    );
    const purple = Color(0xFFB07CFF);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(23, 28), width: 22, height: 34),
      Paint()
        ..color = purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(23, 28), width: 10, height: 20),
      Paint()..color = purple.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(_PortalPainter old) => false;
}

// ---------------------------------------------------------------------------
// Quest window

class _QuestWindow extends StatelessWidget {
  const _QuestWindow({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final floor = model.floorToday;
    final tasks = model.tasks;
    final goals = [
      for (final t in tasks)
        if (!t.isCap) t,
    ];
    final cleared = goals.where(model.isDone).length;
    final complete = model.isQuestComplete;
    final hasCap = tasks.any((t) => t.isCap);
    final now = model.now;
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final deadline = model.deadlineToday ?? midnight;
    final left = deadline.isAfter(now)
        ? deadline.difference(now)
        : Duration.zero;
    final sysName = model.systemSpec?.name.split(' ').first.toUpperCase() ?? '';
    final title = switch (floor) {
      1 || 2 => '[ DUNGEON · FLOOR $floor ]',
      3 => '[ RANK TRIAL ]',
      _ => '[ DAILY QUEST ]',
    };
    final warn = complete
        ? (floor > 0
              ? 'Floor cleared. The next floor opens tomorrow.'
              : 'Penalty avoided. The next quest issues at 00:00.')
        : floor > 0
        ? 'Fail this floor and the Dungeon Penalty follows.'
        : 'Failure to complete will result in a penalty.';
    final s = model.state;
    return HudFrame(
      padding: EdgeInsets.zero,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Hud.head(
                14,
                p.hi,
                spacing: .26,
              ).copyWith(shadows: p.textGlow(.8)),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: p.sys.withValues(alpha: .18)),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  // A plain Spacer would claim half the row and cut the
                  // System name short.
                  flex: 12,
                  child: Text(
                    'RANK ${model.rank.name.toUpperCase()} · $sysName',
                    overflow: TextOverflow.ellipsis,
                    style: Hud.mono(10, p.dim, spacing: .16),
                  ),
                ),
                if (floor == 1 || floor == 2) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: HudPalette.dungeon.sys),
                    ),
                    child: Text(
                      floor == 2 ? '+50%' : '+25%',
                      style: Hud.mono(9, const Color(0xFFFFB3BD)),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '$cleared / ${goals.length} CLEARED',
                  style: Hud.mono(
                    10,
                    complete ? Hud.gold : p.dim,
                    spacing: .16,
                  ),
                ),
              ],
            ),
          ),
          if (complete)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Hud.gold.withValues(alpha: .06),
                border: Border(
                  bottom: BorderSide(color: Hud.gold.withValues(alpha: .3)),
                ),
              ),
              child: Text(
                hasCap
                    ? 'All objectives complete. Cap holds until 23:59.'
                    : 'All objectives complete.',
                textAlign: TextAlign.center,
                style: Hud.head(13, Hud.gold, spacing: .1),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _Objective(model: model, task: tasks[i], index: i),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: p.sys.withValues(alpha: .18)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Kicker(
                        floor == 2 ? 'Floor closes 18:00 in' : 'Time remaining',
                      ),
                    ),
                    Text(
                      hms(left),
                      style: Hud.mono(
                        24,
                        !complete && left.inMinutes < 60
                            ? Hud.warn
                            : Colors.white,
                        weight: FontWeight.w700,
                      ).copyWith(shadows: p.textGlow(.6)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(warn, style: Hud.mono(11, complete ? Hud.gold : Hud.warn)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('XP', style: Hud.mono(10, p.dim, spacing: .1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: XpBar(
                        xp: s.xp,
                        max: model.xpToNext,
                        pending: complete ? model.xpReward : 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        text: '${s.xp} / ${model.xpToNext}',
                        style: Hud.mono(10, p.text, weight: FontWeight.w700),
                        children: [
                          TextSpan(
                            text: ' +${model.xpReward}',
                            style: Hud.mono(
                              10,
                              Hud.gold,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One objective

class _Objective extends StatelessWidget {
  const _Objective({
    required this.model,
    required this.task,
    required this.index,
  });

  final GameModel model;
  final TaskDefinition task;
  final int index;

  String _reading(int v) {
    switch (task.type) {
      case TaskType.timer:
        return '${min(100, (v * 100 / task.goal).floor())}%';
      case TaskType.phoneFree:
        return '${v ~/ 60} / ${task.target} min';
      case TaskType.distance:
        return '${(min(v, task.goal) / 1000).toStringAsFixed(1)} / ${(task.goal / 1000).toStringAsFixed(1)} km';
      case TaskType.screenCap:
        return model.isMeasured(task)
            ? '$v / ${task.target} min'
            : '— / ${task.target} min';
      case TaskType.checkbox:
        return '${min(v, 1)} / 1';
      case TaskType.counter:
        return '${min(v, task.goal)} / ${task.goal}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final v = model.progress(task);
    final cap = task.isCap;
    final done = !cap && model.isDone(task);
    final over = cap && model.isMeasured(task) && v > task.target;
    final locked = model.pastDeadline && !done;
    final gold = Hud.gold;
    final bar = cap
        ? (task.target == 0 ? (v > 0 ? 1.0 : 0.0) : v / task.target)
        : v / task.goal;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: done
            ? gold.withValues(alpha: .05)
            : p.sys.withValues(alpha: .06),
        border: Border.all(
          color: done
              ? gold.withValues(alpha: .45)
              : p.sys.withValues(alpha: .18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: done
                      ? Icon(Icons.check, size: 18, color: gold)
                      : Text(
                          (index + 1).toString().padLeft(2, '0'),
                          style: Hud.mono(11, p.sys, weight: FontWeight.w700),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.name,
                    style: Hud.mono(
                      13,
                      done ? gold : p.text,
                    ).copyWith(height: 1.35),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _reading(v),
                  style: Hud.mono(
                    14,
                    done
                        ? gold
                        : over
                        ? const Color(0xFFFF3B4A)
                        : Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
                if (task.type == TaskType.checkbox && !done && !locked) ...[
                  const SizedBox(width: 10),
                  HoldSquare(
                    semanticLabel: 'Hold to confirm ${task.name}',
                    onConfirmed: () => model.setProgress(task, 1),
                  ),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: done
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (task.type != TaskType.checkbox) ...[
                        SizedBox(height: cap ? 10 : 8),
                        _Bar(
                          value: bar.clamp(0, 1).toDouble(),
                          height: cap ? 8 : 3,
                          color: cap
                              ? (over
                                    ? const Color(0xFFFF3B4A)
                                    : Hud.rankColor(Rank.d))
                              : p.sys,
                          limit: cap,
                        ),
                      ],
                      if (locked) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Deadline passed. This floor can no longer be cleared.',
                          style: Hud.mono(11, Hud.warn),
                        ),
                      ] else
                        ..._controls(context, v, over),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _controls(BuildContext context, int v, bool over) {
    final p = HudScope.of(context);
    Widget steps(List<int> values, String Function(int) label, int undoStep) =>
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              for (final s in values) ...[
                Expanded(
                  child: StepButton(
                    label(s),
                    onPressed: () => model.addProgress(task, s),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              SizedBox(
                width: 48,
                child: StepButton(
                  '↺',
                  undo: true,
                  semanticLabel: 'Undo ${task.name}',
                  onPressed: v > 0
                      ? () => model.addProgress(task, -undoStep)
                      : null,
                ),
              ),
            ],
          ),
        );
    switch (task.type) {
      case TaskType.checkbox:
        return const [];
      case TaskType.counter:
        final s = task.target >= 20
            ? [1, 5, 10]
            : task.target >= 10
            ? [1, 5]
            : [1];
        return [steps(s, (n) => '+$n', 1)];
      case TaskType.distance:
        return [
          steps(const [100, 500], (n) => '+$n m', 100),
        ];
      case TaskType.timer:
        return [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _TimerClock(model: model, task: task),
          ),
        ];
      case TaskType.phoneFree:
        return [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Block(model: model, task: task),
          ),
        ];
      case TaskType.screenCap:
        final measured = model.isMeasured(task);
        final status = !measured
            ? 'NOT MEASURED'
            : over
            ? 'EXCEEDED'
            : '${task.target - v} MIN LEFT';
        return [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  model.capsMeasurable
                      ? 'MEASURED · LOWER IS BETTER'
                      : 'NO USAGE ACCESS · CONFIRM ON YOUR WORD',
                  style: Hud.mono(10, p.dim, spacing: .12),
                ),
              ),
              Text(
                status,
                style: Hud.mono(
                  10,
                  over ? const Color(0xFFFF3B4A) : Hud.rankColor(Rank.d),
                  spacing: .12,
                ),
              ),
            ],
          ),
          if (!model.capsMeasurable && !measured) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hold to confirm you stayed under the cap today.',
                    style: Hud.mono(11, p.dim),
                  ),
                ),
                HoldSquare(
                  semanticLabel: 'Hold to confirm under the cap',
                  onConfirmed: () => model.confirmCap(task),
                ),
              ],
            ),
          ],
        ];
    }
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.height,
    required this.color,
    this.limit = false,
  });

  final double value;
  final double height;
  final Color color;
  final bool limit;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0x2E7D8BA8))),
        FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .55), blurRadius: 8),
              ],
            ),
          ),
        ),
        if (limit)
          const Positioned(
            right: 0,
            top: -2,
            bottom: -2,
            child: SizedBox(width: 2, child: ColoredBox(color: Hud.warn)),
          ),
      ],
    ),
  );
}

/// Ring clock for timed objectives: progress ring, ticks, time remaining.
class _TimerClock extends StatelessWidget {
  const _TimerClock({required this.model, required this.task});
  final GameModel model;
  final TaskDefinition task;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final v = model.progress(task);
    final running = model.isTimerRunning(task);
    final left = Duration(seconds: max(0, task.goal - v));
    final mmss =
        '${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: CustomPaint(
            painter: _RingPainter(
              v / task.goal,
              running ? p.hi : p.sys,
              running,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mmss,
                    style: Hud.mono(20, Colors.white, weight: FontWeight.w700),
                  ),
                  Text('REMAINING', style: Hud.mono(8, p.dim, spacing: .12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CutButton(
                running
                    ? 'PAUSE'
                    : v > 0
                    ? 'RESUME'
                    : 'START',
                onPressed: () => model.toggleTimer(task),
              ),
              const SizedBox(height: 6),
              Text(
                running ? 'RUNNING' : 'Pausing keeps your progress.',
                textAlign: TextAlign.center,
                style: Hud.mono(10, running ? p.hi : p.dim, spacing: .1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.glow);
  final double value;
  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 48.0;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x337D8BA8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * value.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = glow ? const MaskFilter.blur(BlurStyle.solid, 4) : null,
    );
    final tick = Paint()
      ..color = const Color(0x73A9DCFF)
      ..strokeWidth = 1;
    for (var k = 0; k < 12; k++) {
      final a = k / 12 * 2 * pi;
      canvas.drawLine(
        c + Offset(sin(a) * 40, -cos(a) * 40),
        c + Offset(sin(a) * 36, -cos(a) * 36),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.glow != glow;
}

/// A phone-free block: start it, see it run with the apps locked, hold to
/// end it.
class _Block extends StatelessWidget {
  const _Block({required this.model, required this.task});
  final GameModel model;
  final TaskDefinition task;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final running = model.isTimerRunning(task);
    final secs = model.runningSeconds(task);
    final t = Duration(seconds: secs);
    final clock = t.inHours > 0
        ? hms(t)
        : '${t.inMinutes.toString().padLeft(2, '0')}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (running) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Hud.warn.withValues(alpha: .06),
              border: Border.all(color: Hud.warn.withValues(alpha: .4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    clock,
                    style: Hud.mono(22, Colors.white, weight: FontWeight.w700),
                  ),
                ),
                Text(
                  'APPS LOCKED',
                  style: Hud.mono(10, Hud.warn, spacing: .14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          HudScope(
            palette: HudPalette.penalty,
            child: ChargeButton(
              label: 'HOLD TO END BLOCK',
              danger: true,
              onConfirmed: () => model.toggleTimer(task),
            ),
          ),
        ] else ...[
          CutButton(
            'START BLOCK',
            danger: true,
            onPressed: () => model.toggleTimer(task),
          ),
          const SizedBox(height: 6),
          Text(
            'Only the longest single block counts. Chosen apps lock while it runs.',
            textAlign: TextAlign.center,
            style: Hud.mono(10, p.dim).copyWith(height: 1.4),
          ),
        ],
      ],
    );
  }
}
