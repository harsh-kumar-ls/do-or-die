import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/tasks.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/fill_column.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

class QuestScreen extends StatelessWidget {
  const QuestScreen({
    super.key,
    required this.model,
    required this.onOpenPenalty,
  });

  final GameModel model;
  final VoidCallback onOpenPenalty;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Ticker1s(
      builder: (context) {
        model.checkCompletion();
        final now = model.now;
        final midnight = DateTime(now.year, now.month, now.day + 1);
        final deadline = model.deadlineToday ?? midnight;
        final left = deadline.isAfter(now)
            ? deadline.difference(now)
            : Duration.zero;
        final complete = model.isQuestComplete;
        final floor = model.floorToday;
        final trial = model.systemSpec?.at(model.rank).trial;
        final (title, subtitle) = switch (floor) {
          1 => (
            '[ DUNGEON · FLOOR 1 ]',
            'The daily quest, 25% harder. Clear it before the day ends.',
          ),
          2 => (
            '[ DUNGEON · FLOOR 2 ]',
            'The daily quest, 50% harder. Clear it before 18:00.',
          ),
          3 => ('[ RANK TRIAL ]', trial?.summary ?? 'The boss of this rank.'),
          _ => (
            '[ DAILY QUEST ]',
            'Complete every objective before the day ends.',
          ),
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (model.blockerOffline) ...[
                _AlertBanner(
                  title: 'BLOCKER OFFLINE',
                  body: 'The Penalty Zone service is off, so locks cannot be enforced.',
                  action: 'FIX',
                  onTap: onOpenPenalty,
                ),
                const SizedBox(height: 12),
              ],
              if (model.manualClock) ...[
                _AlertBanner(
                  title: 'MANUAL CLOCK',
                  body: "Automatic date and time is off, so the phone's clock can't be trusted.",
                  action: 'FIX',
                  onTap: model.openDateSettings,
                ),
                const SizedBox(height: 12),
              ],
              if (model.notificationsBlocked) ...[
                _AlertBanner(
                  title: 'NOTICES BLOCKED',
                  body:
                      'Deadline warnings and penalty alerts cannot reach you.',
                  action: 'ALLOW',
                  onTap: model.requestNotifications,
                ),
                const SizedBox(height: 12),
              ],
              if (model.lateNotices) ...[
                _AlertBanner(
                  title: 'LATE NOTICES',
                  body: 'Warnings can arrive up to an hour late. Allow "Alarms & reminders" for on-time alerts.',
                  action: 'ALLOW',
                  onTap: model.requestExactTiming,
                ),
                const SizedBox(height: 12),
              ],
              if (model.inPenalty) ...[
                _PenaltyBanner(
                  onTap: onOpenPenalty,
                  dungeon: model.dungeonPenalty,
                ),
                const SizedBox(height: 12),
              ],
              if (model.gate != null) ...[
                _GateBanner(model: model),
                const SizedBox(height: 12),
              ] else if (model.systems?.dungeon != null && floor == 0) ...[
                _AlertBanner(
                  title: 'DUNGEON AHEAD',
                  body: 'Floor 1 begins at 00:00. Floor 2 must be cleared by 18:00.',
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: model.tasks.isEmpty && model.canChooseSystem
                    ? SystemWindow(
                        title: '[ SYSTEM COMPLETE ]',
                        child: Text(
                          'No quest is issued until the next System is chosen. Choose it on the Status tab.',
                          textAlign: TextAlign.center,
                          style: Hud.mono(13, p.text).copyWith(height: 1.5),
                        ),
                      )
                    : SystemWindow(
                        expand: true,
                        title: title,
                        subtitle: subtitle,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _TaskList(model: model)),
                            _DashedLine(color: p.sys),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  floor == 2 ? 'UNTIL 18:00' : 'TIME REMAINING',
                                  style: Hud.mono(11, p.dim, spacing: .06),
                                ),
                                Text(
                                  hms(left),
                                  style: Hud.mono(
                                    13,
                                    p.text,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                complete
                                    ? 'All objectives complete.'
                                    : floor > 0
                                    ? 'Failure brings the Dungeon Penalty: double lock, double reps.'
                                    : 'Failure to complete will result in a penalty.',
                                key: ValueKey(complete),
                                textAlign: TextAlign.center,
                                style: Hud.mono(
                                  11,
                                  complete ? Hud.gold : Hud.warn,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              _XpWindow(model: model, pending: complete),
            ],
          ),
        );
      },
    );
  }
}

/// Spreads the objectives evenly over the window's height, and scrolls if
/// there are too many to fit.
class _TaskList extends StatelessWidget {
  const _TaskList({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return FillColumn(
      children: [
        for (final (i, t) in model.tasks.indexed) ...[
          if (i > 0) _DashedLine(color: p.sys),
          _TaskRow(model: model, task: t),
        ],
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.model, required this.task});

  final GameModel model;
  final TaskDefinition task;

  bool get _isClock =>
      task.type == TaskType.timer || task.type == TaskType.phoneFree;

  /// The figure on the right of the row.
  String _reading(int progress) {
    switch (task.type) {
      case TaskType.timer:
      case TaskType.phoneFree:
        return '${(progress * 100 / task.goal).floor().clamp(0, 100)}%';
      case TaskType.distance:
        return '${_km(progress.clamp(0, task.goal))} / ${_km(task.goal)} km';
      case TaskType.screenCap:
        return model.isMeasured(task)
            ? '$progress / ${task.target} min'
            : '— / ${task.target} min';
      case TaskType.checkbox:
      case TaskType.counter:
        return '${progress.clamp(0, task.goal)} / ${task.goal}';
    }
  }

  static String _km(int metres) => (metres / 1000).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final progress = model.progress(task);
    final done = model.isDone(task);
    final cap = task.isCap;
    final over = cap && model.isMeasured(task) && !done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  task.name,
                  style: Hud.mono(15, done ? p.dim : p.text),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _reading(progress),
                style: Hud.mono(
                  15,
                  over
                      ? Hud.warn
                      : done
                      ? Hud.gold
                      : p.hi,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_isClock) ...[
            const SizedBox(height: 10),
            _TimerClock(model: model, task: task),
          ],
          const SizedBox(height: 10),
          HudBar(
            value: cap
                ? (task.target == 0
                      ? (progress > 0 ? 1 : 0)
                      : progress / task.target)
                : progress / task.goal,
            done: done,
          ),
          const SizedBox(height: 10),
          if (model.pastDeadline && !done)
            Text(
              'Deadline passed. This floor can no longer be cleared.',
              textAlign: TextAlign.center,
              style: Hud.mono(11, Hud.warn),
            )
          else
            _controls(context, done),
        ],
      ),
    );
  }

  Widget _controls(BuildContext context, bool done) {
    final p = HudScope.of(context);
    switch (task.type) {
      case TaskType.checkbox:
        return HoldButton(
          label: 'HOLD TO CONFIRM',
          doneLabel: 'CONFIRMED',
          done: done,
          onConfirmed: () => model.setProgress(task, 1),
        );
      case TaskType.timer:
        final running = model.isTimerRunning(task);
        final started = model.progress(task) > 0;
        return HudButton(
          running
              ? 'PAUSE'
              : done
              ? 'TARGET REACHED · CONTINUE'
              : started
              ? 'RESUME'
              : 'START',
          onPressed: () => model.toggleTimer(task),
        );
      case TaskType.phoneFree:
        final running = model.isTimerRunning(task);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HudButton(
              running
                  ? 'END BLOCK'
                  : done
                  ? 'TARGET REACHED · NEW BLOCK'
                  : 'START BLOCK',
              onPressed: () => model.toggleTimer(task),
            ),
            const SizedBox(height: 6),
            Text(
              running ? 'Chosen apps are locked until the block ends.' : 'Only the longest single block counts. Chosen apps lock while it runs.',
              textAlign: TextAlign.center,
              style: Hud.mono(10, p.dim),
            ),
          ],
        );
      case TaskType.counter:
        final steps = task.target >= 20
            ? [1, 5, 10]
            : task.target >= 10
            ? [1, 5]
            : [1];
        return _steps(steps, done, (s) => '+$s');
      case TaskType.distance:
        return _steps(const [100, 500], done, (s) => '+$s m');
      case TaskType.screenCap:
        if (model.capsMeasurable) {
          return Text(
            'Measured from usage access on the chosen apps. Lower is better.',
            textAlign: TextAlign.center,
            style: Hud.mono(10, p.dim),
          );
        }
        return HoldButton(
          label: 'HOLD TO CONFIRM UNDER LIMIT',
          doneLabel: 'CONFIRMED · HONOUR',
          done: done,
          onConfirmed: () => model.confirmCap(task),
        );
    }
  }

  Widget _steps(List<int> steps, bool done, String Function(int) label) => Row(
    children: [
      for (final (i, s) in steps.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: HudButton(
            label(s),
            onPressed: done ? null : () => model.addProgress(task, s),
          ),
        ),
      ],
    ],
  );
}

/// Large HH:MM:SS clock for timer objectives, ticking while it runs.
class _TimerClock extends StatelessWidget {
  const _TimerClock({required this.model, required this.task});

  final GameModel model;
  final TaskDefinition task;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final seconds = model.progress(task);
    final running = model.isTimerRunning(task);
    final done = model.isDone(task);
    final left = Duration(seconds: (task.goal - seconds).clamp(0, task.goal));
    final color = done ? Hud.gold : (running ? Colors.white : p.hi);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: p.sys.withValues(alpha: running ? .08 : .03),
        border: Border.all(
          color: p.sys.withValues(alpha: running ? p.lineAlpha + .15 : .18),
        ),
      ),
      child: Column(
        children: [
          Text(
            hms(Duration(seconds: seconds)),
            style: Hud.head(38, color, spacing: .06).copyWith(
              height: 1,
              shadows: running ? p.textGlow(1.4) : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (running)
                    Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: p.sys,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: p.glowColor, blurRadius: p.glow),
                            ],
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeOut(duration: 700.ms),
                  if (running) const SizedBox(width: 6),
                  Text(
                    running
                        ? 'RUNNING'
                        : done
                        ? 'COMPLETE'
                        : seconds > 0
                        ? 'PAUSED'
                        : 'NOT STARTED',
                    style: Hud.mono(10, running ? p.hi : p.dim, spacing: .14),
                  ),
                ],
              ),
              Text(
                done
                    ? 'GOAL ${hms(Duration(seconds: task.goal))}'
                    : '${hms(left)} LEFT',
                style: Hud.mono(10, p.dim, spacing: .08),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _XpWindow extends StatelessWidget {
  const _XpWindow({required this.model, required this.pending});

  final GameModel model;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final s = model.state;
    return SystemWindow(
      delay: const Duration(milliseconds: 120),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(
                TextSpan(
                  text: 'LV. ',
                  style: Hud.mono(12, p.dim),
                  children: [
                    TextSpan(text: '${s.level}', style: Hud.mono(12, p.text)),
                  ],
                ),
              ),
              Text(
                pending
                    ? '${s.xp} (+${model.xpReward}) / ${model.xpToNext} XP'
                    : '${s.xp} / ${model.xpToNext} XP',
                style: Hud.mono(12, pending ? Hud.gold : p.dim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HudBar(value: s.xp / model.xpToNext, height: 6),
        ],
      ),
    );
  }
}

/// A compact System alert with one action, shown above the quest.
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.title,
    required this.body,
    this.action,
    this.onTap,
  });

  final String title;
  final String body;

  /// Null for an information-only banner.
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Semantics(
      container: true,
      button: true,
      label: '$title. $body ${action ?? ''}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: p.panel,
            border: Border.all(color: Hud.warn.withValues(alpha: .6)),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Hud.head(11, Hud.warn, spacing: .2)),
                      const SizedBox(height: 3),
                      Text(body, style: Hud.mono(11, p.text)),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 10),
                  Text('$action ›', style: Hud.mono(11, p.hi)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PenaltyBanner extends StatelessWidget {
  const _PenaltyBanner({required this.onTap, this.dungeon = false});
  final VoidCallback onTap;
  final bool dungeon;

  @override
  Widget build(BuildContext context) {
    final pal = dungeon ? HudPalette.dungeon : HudPalette.penalty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: pal.panel,
          border: Border.all(color: pal.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dungeon ? 'DUNGEON PENALTY ACTIVE' : 'PENALTY ZONE ACTIVE',
                style: Hud.head(
                  12,
                  pal.hi,
                  spacing: .2,
                ).copyWith(shadows: pal.textGlow(.6)),
              ),
            ),
            Text('OPEN ›', style: Hud.mono(11, pal.hi)),
          ],
        ),
      ),
    );
  }
}

/// An open Gate: its rank, time left, and a hold to enter.
class _GateBanner extends StatelessWidget {
  const _GateBanner({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final gate = model.gate!;
    final c = Hud.rankColor(gate.from);
    final left = gate.expiresAt.difference(model.now);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .08),
        border: Border.all(color: c.withValues(alpha: .7)),
        boxShadow: [BoxShadow(color: c.withValues(alpha: .25), blurRadius: 18)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RANK ${gate.from.name.toUpperCase()} GATE OPEN',
                  style: Hud.head(13, c, spacing: .18),
                ),
              ),
              Text(
                left.isNegative ? 'CLOSING' : hms(left),
                style: Hud.mono(12, c, weight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Three floors on three days. The third is the Rank Trial. Failing any floor brings the Dungeon Penalty.',
            style: Hud.mono(11, HudScope.of(context).dim).copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          HoldButton(
            label: 'HOLD TO ENTER THE GATE',
            doneLabel: 'ENTERED',
            holdFor: const Duration(milliseconds: 1500),
            onConfirmed: model.enterGate,
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter(color.withValues(alpha: .16))),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 3, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
