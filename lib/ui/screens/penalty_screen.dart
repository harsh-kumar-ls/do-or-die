import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/game_service.dart';
import '../../domain/day.dart';
import '../../domain/penalty.dart';
import '../../platform/blocker.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_kit.dart';
import '../widgets/system_frame.dart';
import 'quest_screen.dart' show QuestScreen;

/// The Penalty tab, built from design/claude-design/penalty.html, in the
/// Penalty Zone (red, glitching) or Dungeon Penalty (crimson and gold,
/// still and ceremonial) look: lock countdown, locked apps, the 15-minute
/// release and its tally, and the System-specific debt.
class PenaltyScreen extends StatelessWidget {
  const PenaltyScreen({
    super.key,
    required this.model,
    required this.blocker,
    required this.onEditApps,
  });

  final GameModel model;
  final AppBlocker blocker;
  final VoidCallback onEditApps;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Ticker1s(
      builder: (context) {
        final dungeon = model.dungeonPenalty;
        final debt = model.state.debt;
        final owes = debt != null && debt.dueDay == model.service.today;
        final lock = model.state.lock;
        final lockToday = lock != null && lock.day == model.service.today;
        final any = model.inPenalty;
        final failedDay = lockToday ? lock.day.addDays(-1) : null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SysTopBar(
                now: model.now,
                kicker: dungeon
                    ? 'DUNGEON FLOOR FAILED · ${model.systemSpec?.name.split(' ').first.toUpperCase() ?? ''}'
                    : QuestScreen.kicker(model),
                rank: model.rank,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    if (blocker.canBlock) _EnforcementStatus(blocker: blocker),
                    const SizedBox(height: 4),
                    if (dungeon) ...[
                      const Center(child: _Seal(size: 44)),
                      const SizedBox(height: 6),
                    ],
                    Center(
                      child: _GlitchTitle(
                        dungeon ? '[ DUNGEON PENALTY ]' : '[ PENALTY ZONE ]',
                        glitch: !dungeon && any,
                        size: dungeon ? 20 : 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      !any
                          ? 'No penalty is in effect.'
                          : dungeon
                          ? 'The Dungeon was not cleared. The Gate is shut for 7 days.'
                          : failedDay == null
                          ? 'A penalty is in effect today.'
                          : 'Daily quest failed · ${dayLabel(DateTime(failedDay.year, failedDay.month, failedDay.day))}',
                      textAlign: TextAlign.center,
                      style: Hud.mono(
                        11,
                        p.hi.withValues(alpha: .85),
                      ).copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _LockPanel(
                      model: model,
                      blocker: blocker,
                      onEditApps: onEditApps,
                    ),
                    if (model.lockActive || model.lockReleased) ...[
                      const SizedBox(height: 12),
                      _Release(model: model),
                    ],
                    if (model.lockActive ||
                        model.lockReleased ||
                        model.lockPending)
                      _EmergencyExit(model: model),
                    if (model.service.contestableDay != null) ...[
                      const SizedBox(height: 12),
                      _Contest(model: model),
                    ],
                    if (owes) ...[
                      const SizedBox(height: 12),
                      _DebtPanel(model: model, debt: debt, dungeon: dungeon),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Title and seal

/// The Penalty Zone title: a short glitch burst every 2.6 s (offset red and
/// pale copies, jitter). Still when reduce-motion is on or [glitch] is off.
class _GlitchTitle extends StatefulWidget {
  const _GlitchTitle(this.text, {required this.glitch, required this.size});
  final String text;
  final bool glitch;
  final double size;

  @override
  State<_GlitchTitle> createState() => _GlitchTitleState();
}

class _GlitchTitleState extends State<_GlitchTitle>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final style = Hud.head(
      widget.size,
      p.hi,
      spacing: .24,
    ).copyWith(shadows: p.textGlow(1));
    final text = Text(widget.text, style: style);
    if (!widget.glitch || MediaQuery.of(context).disableAnimations) return text;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final on = t > .9 && t < .96;
        if (!on) return text;
        final dx = t < .92
            ? -3.0
            : t < .94
            ? 3.0
            : -2.0;
        return Stack(
          children: [
            text,
            Transform.translate(
              offset: Offset(dx, 0),
              child: ClipRect(
                clipper: _Slice(t < .93 ? .1 : .6, t < .93 ? .45 : .92),
                child: Text(
                  widget.text,
                  style: style.copyWith(color: const Color(0xFFFF9AA2)),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(-dx, 1),
              child: ClipRect(
                clipper: _Slice(t < .93 ? .45 : .05, t < .93 ? .75 : .3),
                child: Text(
                  widget.text,
                  style: style.copyWith(color: const Color(0xFF5A0B12)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Slice extends CustomClipper<Rect> {
  _Slice(this.top, this.bottom);
  final double top;
  final double bottom;

  @override
  Rect getClip(Size s) =>
      Rect.fromLTRB(0, s.height * top, s.width, s.height * bottom);

  @override
  bool shouldReclip(_Slice old) => old.top != top || old.bottom != bottom;
}

/// The Dungeon seal: a crimson diamond with a gold cross, a dashed ring
/// turning once every 40 s.
class _Seal extends StatefulWidget {
  const _Seal({required this.size});
  final double size;

  @override
  State<_Seal> createState() => _SealState();
}

class _SealState extends State<_Seal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => CustomPaint(
      size: Size.square(widget.size),
      painter: SealPainter(_c.value),
    ),
  );
}

class SealPainter extends CustomPainter {
  SealPainter(this.turn);
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 44);
    final c = const Offset(22, 22);
    final gold = Paint()
      ..color = Hud.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(22, 22);
    canvas.rotate(turn * 2 * pi);
    for (var a = 0.0; a < 2 * pi; a += 6 / 20) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 20),
        a,
        3 / 20,
        false,
        gold,
      );
    }
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(22, 6)
        ..lineTo(36, 22)
        ..lineTo(22, 38)
        ..lineTo(8, 22)
        ..close(),
      Paint()
        ..color = const Color(0xFFD7263D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final x = Paint()
      ..color = Hud.gold
      ..strokeWidth = 1.6;
    canvas
      ..drawLine(c + const Offset(-7, -6), c + const Offset(7, 6), x)
      ..drawLine(c + const Offset(7, -6), c + const Offset(-7, 6), x);
  }

  @override
  bool shouldRepaint(SealPainter old) => old.turn != turn;
}

// ---------------------------------------------------------------------------
// Lock panel

class _LockPanel extends StatefulWidget {
  const _LockPanel({
    required this.model,
    required this.blocker,
    required this.onEditApps,
  });
  final GameModel model;
  final AppBlocker blocker;
  final VoidCallback onEditApps;

  @override
  State<_LockPanel> createState() => _LockPanelState();
}

class _LockPanelState extends State<_LockPanel> {
  Map<String, String> _labels = const {};

  /// The phone's app names have arrived (or failed to); until then the chips
  /// stay hidden so a short fallback name never flashes first.
  bool _labelsLoaded = false;

  static const _fallback = {
    'com.instagram.android': 'Instagram',
    'com.google.android.youtube': 'YouTube',
    'com.pubg.imobile': 'BGMI',
  };

  @override
  void initState() {
    super.initState();
    widget.blocker
        .installedApps()
        .then((apps) {
          if (mounted) {
            setState(() {
              _labels = {for (final a in apps) a.package: a.label};
              _labelsLoaded = true;
            });
          }
        })
        .catchError((Object _) {
          if (mounted) setState(() => _labelsLoaded = true);
        });
  }

  String _name(String pkg) =>
      _labels[pkg] ?? _fallback[pkg] ?? pkg.split('.').last;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final m = widget.model;
    final lock = m.state.lock;
    final now = m.now;
    final String big;
    final String cap;
    var dimBig = false;
    if (m.lockActive) {
      big = hms(lock!.effectiveEnd.difference(now));
      cap = 'UNTIL ACCESS IS RESTORED';
    } else if (m.lockReleased) {
      big = hms(lock!.effectiveEnd.difference(now));
      final r = m.releaseEndsAt!.difference(now);
      cap =
          'RELEASED · LOCK RESUMES IN ${r.inMinutes.toString().padLeft(2, '0')}:${(r.inSeconds % 60).toString().padLeft(2, '0')}';
    } else if (m.lockPending) {
      // The user chose the lock time, so it is shown: a countdown to it.
      big = hms(lock!.start.difference(now));
      final st = lock.start;
      cap =
          'LOCK BEGINS AT ${st.hour.toString().padLeft(2, '0')}:${st.minute.toString().padLeft(2, '0')}';
      dimBig = true;
    } else if (lock != null &&
        !now.isBefore(lock.effectiveEnd) &&
        DayKey.fromDateTime(lock.start) == m.service.today) {
      // Only on the day the lock ran; the record stays in state afterwards.
      big = '--:--:--';
      cap = 'LOCK SERVED · ACCESS RESTORED';
      dimBig = true;
    } else {
      big = '--:--:--';
      cap = 'NO LOCK TODAY';
      dimBig = true;
    }
    final apps = m.service.blockedToday.toList()
      ..sort((a, b) => _name(a).compareTo(_name(b)));
    final open = !m.lockActive;
    final hours = lock == null
        ? 0
        : (lock.end.difference(lock.start).inMinutes / 60).round();
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(
            big,
            style: Hud.mono(
              46,
              dimBig ? p.hi.withValues(alpha: .75) : Colors.white,
              weight: FontWeight.w700,
            ).copyWith(shadows: p.textGlow(1), height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            cap,
            textAlign: TextAlign.center,
            style: Hud.head(12, p.hi, spacing: .2),
          ),
          if (lock != null && lock.day == m.service.today) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Meta(
                  m.dungeonPenalty ? '$hours H LOCK · ×2' : '$hours H LOCK',
                  gold: m.dungeonPenalty,
                ),
                const SizedBox(width: 8),
                _Meta('${apps.length} APP${apps.length == 1 ? '' : 'S'}'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (apps.isEmpty)
            Text(
              'No apps chosen. A failed day locks nothing until you choose some.',
              textAlign: TextAlign.center,
              style: Hud.mono(11, Hud.warn),
            )
          else
            AnimatedOpacity(
              opacity: _labelsLoaded ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final pkg in apps) _AppChip(_name(pkg), open: open),
                ],
              ),
            ),
          const SizedBox(height: 12),
          StepButton('EDIT LOCKED APPS', onPressed: widget.onEditApps),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.text, {this.gold = false});
  final String text;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final c = gold ? Hud.gold : p.hi;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(
          color: gold ? Hud.gold : p.sys.withValues(alpha: .25),
        ),
      ),
      child: Text(text, style: Hud.mono(10, c, spacing: .14)),
    );
  }
}

class _AppChip extends StatelessWidget {
  const _AppChip(this.name, {required this.open});
  final String name;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    const green = Color(0xFF5BD69A);
    final c = open ? green : p.text;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: open
            ? green.withValues(alpha: .06)
            : p.sys.withValues(alpha: .07),
        border: Border.all(
          color: open
              ? green.withValues(alpha: .5)
              : p.sys.withValues(alpha: .6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(open ? Icons.lock_open : Icons.lock, size: 12, color: c),
          const SizedBox(width: 6),
          Text(name, style: Hud.mono(11, c)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Release

class _Release extends StatelessWidget {
  const _Release({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final used = model.releasesUsed;
    final left = model.service.releasesLeft;
    final total = used + left;
    final active = model.lockReleased;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active)
          Opacity(
            opacity: .45,
            child: CutButton('RELEASE ACTIVE', onPressed: null),
          )
        else if (left == 0)
          Opacity(
            opacity: .45,
            child: CutButton('NO RELEASES LEFT', onPressed: null),
          )
        else
          ChargeButton(
            key: ValueKey('release-$used'),
            label: 'HOLD 3S · RELEASE 15 MIN',
            danger: true,
            holdFor: const Duration(seconds: 3),
            onConfirmed: () async {
              final ok = await model.releaseLock();
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Release ${model.releasesUsed} of $total logged. '
                      'Apps open for 15 minutes.',
                    ),
                  ),
                );
              }
            },
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('RELEASES LEFT', style: Hud.mono(11, p.dim, spacing: .14)),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 4,
                children: [
                  for (var k = 0; k < total; k++)
                    Container(
                      width: 8,
                      height: 14,
                      decoration: BoxDecoration(
                        color: k < left ? Hud.warn : Colors.transparent,
                        border: Border.all(
                          color: k < left
                              ? Hud.warn
                              : p.sys.withValues(alpha: .25),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '$left / $total',
              style: Hud.mono(11, Hud.warn, weight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

/// Asks for a written reason; returns it, or null when cancelled.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  int minLength = 0,
}) => showDialog<String>(
  context: context,
  builder: (c) => _ReasonDialog(
    title: title,
    body: body,
    confirm: confirm,
    minLength: minLength,
  ),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.body,
    required this.confirm,
    required this.minLength,
  });
  final String title;
  final String body;
  final String confirm;
  final int minLength;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim().length >= widget.minLength;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.body),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('reason'),
            controller: _text,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.minLength > 0
                  ? 'Reason (at least ${widget.minLength} characters)'
                  : 'Reason (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: ok
              ? () => Navigator.of(context).pop(_text.text.trim())
              : null,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

/// The emergency exit: always available while a lock is pending or running.
/// It ends the lock now, and is logged with its reason and shown in the
/// report.
class _EmergencyExit extends StatelessWidget {
  const _EmergencyExit({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return TextButton(
      onPressed: () async {
        final reason = await askReason(
          context,
          title: 'Emergency exit',
          body:
              'Ends the lock now. For real emergencies: it is logged and '
              'shown in your report.',
          confirm: 'END THE LOCK',
        );
        if (reason == null) return;
        final ok = await model.emergencyExit(reason);
        if (ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lock ended. Emergency exit logged.')),
          );
        }
      },
      child: Text('EMERGENCY EXIT', style: Hud.mono(12, p.dim, spacing: .16)),
    );
  }
}

/// Contest a wrongful verdict: one in any 14 days, with a written reason.
class _Contest extends StatelessWidget {
  const _Contest({required this.model});
  final GameModel model;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Judged wrongly? (the phone died, a bug, travel, a limit the '
          'phone could not measure) One verdict in any 14 days can be '
          'contested. The lock and the debt are cancelled; the failure '
          'stays on record.',
          style: Hud.mono(12, p.dim).copyWith(height: 1.5),
        ),
        const SizedBox(height: 8),
        CutButton(
          'CONTEST THIS VERDICT',
          onPressed: () async {
            final reason = await askReason(
              context,
              title: 'Contest the verdict',
              body: 'Say what went wrong. This is kept in your log.',
              confirm: 'CONTEST',
              minLength: GameService.contestReasonMin,
            );
            if (reason == null) return;
            final ok = await model.contestVerdict(reason);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Verdict contested. Lock and debt cancelled.'
                        : 'The verdict could not be contested.',
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Debt

class _DebtPanel extends StatelessWidget {
  const _DebtPanel({
    required this.model,
    required this.debt,
    required this.dungeon,
  });
  final GameModel model;
  final PenaltyDebt debt;
  final bool dungeon;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final parts = <Widget>[];
    void add(Widget w) {
      if (parts.isNotEmpty) {
        parts.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 14),
            color: p.sys.withValues(alpha: .2),
          ),
        );
      }
      parts.add(w);
    }

    switch (debt.kind) {
      case PenaltyKind.exercise:
        add(
          _CountDebt(
            label: 'PUSH-UPS OWED',
            done: debt.primaryDone,
            owed: debt.primaryOwed,
            unit: 'REPS',
            steps: const [1, 10],
            onAdd: (n) => model.recordPenalty(primary: n),
          ),
        );
        if (debt.secondaryOwed > 0) {
          add(
            _CountDebt(
              label: 'SQUATS OWED',
              done: debt.secondaryDone,
              owed: debt.secondaryOwed,
              unit: 'REPS',
              steps: const [1, 10],
              onAdd: (n) => model.recordPenalty(secondary: n),
            ),
          );
        }
      case PenaltyKind.reading:
        add(
          _CountDebt(
            label: 'PAGES OWED',
            done: debt.primaryDone,
            owed: debt.primaryOwed,
            unit: 'PAGES',
            steps: const [1, 5],
            onAdd: (n) => model.recordPenalty(primary: n),
          ),
        );
        if (debt.secondaryOwed > 0) {
          add(_ReflectionDebt(model: model, debt: debt));
        }
      case PenaltyKind.focus:
        add(_BlockDebt(model: model, debt: debt));
      case PenaltyKind.none:
        break;
    }
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dungeon ? '[ DUNGEON DEBT · ×2 ]' : '[ PENALTY DEBT ]',
            textAlign: TextAlign.center,
            style: Hud.head(12, p.hi, spacing: .24),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            color: p.sys.withValues(alpha: .2),
          ),
          ...parts,
          const SizedBox(height: 12),
          Text(
            debt.isPaid
                ? 'Debt cleared. ${dungeon ? 'The Dungeon Penalty' : 'The Penalty Zone'} ends when the lock expires.'
                : 'Clear the debt today. Anything unpaid expires at midnight and is logged.',
            textAlign: TextAlign.center,
            style: Hud.mono(
              11,
              debt.isPaid ? Hud.gold : p.dim,
            ).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _DebtHeader extends StatelessWidget {
  const _DebtHeader(this.label, this.value, this.of);
  final String label;
  final String value;
  final String of;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(label, style: Hud.head(12, p.text, spacing: .18)),
          ),
          Text.rich(
            TextSpan(
              text: value,
              style: Hud.mono(22, Colors.white, weight: FontWeight.w700),
              children: [TextSpan(text: ' / $of', style: Hud.mono(12, p.dim))],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cleared extends StatelessWidget {
  const _Cleared(this.what);
  final String what;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Hud.gold.withValues(alpha: .06),
      border: Border.all(color: Hud.gold.withValues(alpha: .45)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check, size: 18, color: Hud.gold),
        const SizedBox(width: 10),
        Text('$what CLEARED', style: Hud.mono(12, Hud.gold)),
      ],
    ),
  );
}

class _DebtBar extends StatelessWidget {
  const _DebtBar(this.value);
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return SizedBox(
      height: 4,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0x2E7D8BA8))),
          FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.sys,
                boxShadow: [BoxShadow(color: p.glowColor, blurRadius: 8)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountDebt extends StatelessWidget {
  const _CountDebt({
    required this.label,
    required this.done,
    required this.owed,
    required this.unit,
    required this.steps,
    required this.onAdd,
  });

  final String label;
  final int done;
  final int owed;
  final String unit;
  final List<int> steps;
  final ValueChanged<int> onAdd;

  @override
  Widget build(BuildContext context) {
    final paid = done >= owed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DebtHeader(label, '$done', '$owed'),
        _DebtBar(owed == 0 ? 1 : done / owed),
        if (paid)
          _Cleared(label.replaceAll(' OWED', ''))
        else ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in steps) ...[
                Expanded(
                  child: StepButton('+$s $unit', onPressed: () => onAdd(s)),
                ),
                const SizedBox(width: 6),
              ],
              SizedBox(
                width: 48,
                child: StepButton(
                  '↺',
                  undo: true,
                  semanticLabel: 'Undo ${label.toLowerCase()}',
                  onPressed: done > 0 ? () => onAdd(-1) : null,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Personality penalty: five lines of at least four words each, kept in
/// the trial log.
class _ReflectionDebt extends StatefulWidget {
  const _ReflectionDebt({required this.model, required this.debt});
  final GameModel model;
  final PenaltyDebt debt;

  @override
  State<_ReflectionDebt> createState() => _ReflectionDebtState();
}

class _ReflectionDebtState extends State<_ReflectionDebt> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final d = widget.debt;
    final paid = d.secondaryDone >= d.secondaryOwed;
    final n = min(reflectionLineCount(_c.text), reflectionLines);
    final ok = n >= reflectionLines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DebtHeader(
          'PLAN FOR TOMORROW OWED',
          '${d.secondaryDone}',
          '${d.secondaryOwed}',
        ),
        if (paid)
          const _Cleared('PLAN FOR TOMORROW')
        else ...[
          TextField(
            controller: _c,
            minLines: 5,
            maxLines: 9,
            style: Hud.mono(12, p.text).copyWith(height: 1.55),
            cursorColor: p.sys,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.black38,
              hintText: 'Plan tomorrow: when, where and how you will do each objective. One step per line.',
              hintStyle: Hud.mono(12, p.dim),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: p.sys.withValues(alpha: .25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: p.sys),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'A LINE NEEDS 4+ WORDS',
                  style: Hud.mono(10, p.dim, spacing: .12),
                ),
              ),
              Text(
                '$n / $reflectionLines',
                style: Hud.mono(
                  10,
                  ok ? const Color(0xFF5BD69A) : p.hi,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CutButton(
            'SUBMIT',
            onPressed: ok
                ? () async {
                    if (await widget.model.submitReflection(_c.text)) {
                      _c.clear();
                    }
                    if (mounted) setState(() {});
                  }
                : null,
          ),
        ],
      ],
    );
  }
}

/// Focus penalty: a phone-free block with the chosen apps locked.
class _BlockDebt extends StatelessWidget {
  const _BlockDebt({required this.model, required this.debt});
  final GameModel model;
  final PenaltyDebt debt;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final running = model.penaltyBlockRunning;
    final runMin = running ? model.penaltyBlockSeconds ~/ 60 : 0;
    final done = min(debt.primaryOwed, debt.primaryDone + runMin);
    final leftSecs = max(
      0,
      (debt.primaryOwed - debt.primaryDone) * 60 -
          (running ? model.penaltyBlockSeconds : 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DebtHeader('PHONE-FREE MINUTES OWED', '$done', '${debt.primaryOwed}'),
        _DebtBar(debt.primaryOwed == 0 ? 1 : done / debt.primaryOwed),
        if (debt.isPaid && !running)
          const _Cleared('PHONE-FREE BLOCK')
        else ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  hms(Duration(seconds: leftSecs)),
                  style: Hud.mono(
                    30,
                    Colors.white,
                    weight: FontWeight.w700,
                  ).copyWith(shadows: p.textGlow(.8)),
                ),
              ),
              Text(
                running ? 'APPS LOCKED' : 'REMAINING',
                style: Hud.mono(10, running ? p.hi : p.dim, spacing: .14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (running)
            ChargeButton(
              label: 'HOLD TO END BLOCK',
              danger: true,
              onConfirmed: model.togglePenaltyBlock,
            )
          else
            CutButton(
              'START PENALTY BLOCK',
              onPressed: model.togglePenaltyBlock,
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Warns when the Android blocker service is off, so locks can't be enforced.
class _EnforcementStatus extends StatefulWidget {
  const _EnforcementStatus({required this.blocker});
  final AppBlocker blocker;

  @override
  State<_EnforcementStatus> createState() => _EnforcementStatusState();
}

class _EnforcementStatusState extends State<_EnforcementStatus> {
  bool? _enabled;
  late final Timer _poll;

  @override
  void initState() {
    super.initState();
    _check();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final s = await widget.blocker.status();
      if (mounted) setState(() => _enabled = s.serviceEnabled);
    } catch (_) {
      if (mounted) setState(() => _enabled = false);
    }
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled != false) return const SizedBox.shrink();
    final p = HudScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ENFORCEMENT OFFLINE', style: Hud.head(12, p.hi, spacing: .2)),
            const SizedBox(height: 6),
            Text(
              'The Penalty Zone watcher is off, so locks cannot be enforced.',
              style: Hud.mono(11, p.text),
            ),
            const SizedBox(height: 10),
            CutButton(
              'FIX',
              danger: true,
              onPressed: () async {
                final st = await widget.blocker.systemStatus();
                if (!st.usageAccess) return widget.blocker.requestUsageAccess();
                if (!st.overlay) return widget.blocker.requestOverlay();
                await widget.blocker.startWatcher();
              },
            ),
          ],
        ),
      ),
    );
  }
}
