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
        final complete = model.isQuestComplete;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                _PenaltyBanner(onTap: onOpenPenalty),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: SystemWindow(
                  expand: true,
                  title: '[ DAILY QUEST ]',
                  subtitle: 'Complete every objective before the day ends.',
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
                            'TIME REMAINING',
                            style: Hud.mono(11, p.dim, spacing: .06),
                          ),
                          Text(
                            hms(midnight.difference(now)),
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
                              : 'Failure to complete will result in a penalty.',
                          key: ValueKey(complete),
                          textAlign: TextAlign.center,
                          style: Hud.mono(11, complete ? Hud.gold : Hud.warn),
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

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final progress = model.progress(task);
    final done = model.isDone(task);
    final isTimer = task.type == TaskType.timer;
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
              Text(
                isTimer
                    ? '${(progress * 100 / task.goal).floor().clamp(0, 100)}%'
                    : '${progress.clamp(0, task.goal)} / ${task.goal}',
                style: Hud.mono(
                  15,
                  done ? Hud.gold : p.hi,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (isTimer) ...[
            const SizedBox(height: 10),
            _TimerClock(model: model, task: task),
          ],
          const SizedBox(height: 10),
          HudBar(value: progress / task.goal, done: done),
          const SizedBox(height: 10),
          _controls(done),
        ],
      ),
    );
  }

  Widget _controls(bool done) {
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
      case TaskType.counter:
        final steps = task.target >= 20 ? [1, 5, 10] : [1];
        return Row(
          children: [
            for (final (i, s) in steps.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: HudButton(
                  '+$s',
                  onPressed: done ? null : () => model.addProgress(task, s),
                ),
              ),
            ],
          ],
        );
    }
  }
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
      container: true,
      button: true,
      label: '$title. $body $action',
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

class _PenaltyBanner extends StatelessWidget {
  const _PenaltyBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: HudPalette.penalty.panel,
        border: Border.all(color: HudPalette.penalty.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PENALTY ZONE ACTIVE',
              style: Hud.head(
                12,
                HudPalette.penalty.hi,
                spacing: .2,
              ).copyWith(shadows: HudPalette.penalty.textGlow(.6)),
            ),
          ),
          Text('OPEN ›', style: Hud.mono(11, HudPalette.penalty.hi)),
        ],
      ),
    ),
  );
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
