import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/progression.dart';
import '../fx.dart';
import '../theme.dart';
import 'awakening_art.dart';
import 'system_frame.dart';

/// Shared pieces of the Claude Design screens (design/claude-design/*.html):
/// top bar, small rank badge, hold square, step buttons, XP bar, nav icons.

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];
const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// "SAT · 31 OCT".
String dayLabel(DateTime d) =>
    '${_days[d.weekday - 1]} · ${d.day} ${_months[d.month - 1]}';

/// Date, a kicker line, the sound toggle and the small rank badge.
class SysTopBar extends StatelessWidget {
  const SysTopBar({
    super.key,
    required this.now,
    required this.kicker,
    required this.rank,
  });

  final DateTime now;
  final String kicker;
  final Rank rank;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayLabel(now), style: Hud.head(14, p.text, spacing: .2)),
                const SizedBox(height: 2),
                // Shrinks to fit rather than cutting the System name off
                // on narrow phones.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    kicker.toUpperCase(),
                    maxLines: 1,
                    style: Hud.mono(10, p.dim, spacing: .16),
                  ),
                ),
              ],
            ),
          ),
          const SoundToggle(),
          const SizedBox(width: 8),
          RankHexSmall(rank: rank),
        ],
      ),
    );
  }
}

/// 48 x 48 sound toggle, as in the prototypes.
class SoundToggle extends StatelessWidget {
  const SoundToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: Fx.instance.muted,
      builder: (context, muted, _) => Semantics(
        button: true,
        label: muted ? 'Turn sound on' : 'Mute sound',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Fx.instance.setMuted(!muted);
            if (muted) Fx.instance.play(Cue.tap);
          },
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: p.sys.withValues(alpha: .18)),
            ),
            child: Icon(
              muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
              size: 20,
              color: muted ? p.dim : p.hi,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 48 x 52 rank badge in the top bar.
class RankHexSmall extends StatelessWidget {
  const RankHexSmall({super.key, required this.rank, this.width = 48});
  final Rank rank;
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rank ${rank.name.toUpperCase()}',
    child: CustomPaint(
      size: Size(width, width * 124 / 116),
      painter: RankHexPainter(rank),
    ),
  );
}

/// A chamfered step button ("+5", "+100 m", "+1 PAGE").
class StepButton extends StatefulWidget {
  const StepButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.undo = false,
    this.semanticLabel,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool undo;
  final String? semanticLabel;
  final Color? color;

  @override
  State<StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<StepButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final on = widget.onPressed != null;
    final c = widget.color ?? p.hi;
    final edge = widget.undo
        ? p.sys.withValues(alpha: .18)
        : (widget.color ?? p.sys).withValues(alpha: .55);
    return Semantics(
      container: true,
      button: true,
      enabled: on,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: on
            ? () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? .95 : 1,
          duration: const Duration(milliseconds: 100),
          child: Opacity(
            opacity: on ? 1 : .35,
            child: ClipPath(
              clipper: const ChamferClipper(
                6,
                corners: [true, false, true, false],
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (widget.color ?? p.sys).withValues(
                    alpha: _down ? .12 : .04,
                  ),
                  border: Border.all(color: edge),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    widget.label,
                    style: widget.undo
                        ? Hud.mono(15, p.dim)
                        : Hud.mono(13, c, weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hold-to-confirm square (48 x 48) that fills bottom to top over [holdFor].
/// Test builds also accept a click (`DOD_TEST_MODE`).
class HoldSquare extends StatefulWidget {
  const HoldSquare({
    super.key,
    required this.onConfirmed,
    required this.semanticLabel,
    this.holdFor = const Duration(milliseconds: 800),
  });

  final VoidCallback onConfirmed;
  final String semanticLabel;
  final Duration holdFor;

  static const _clickConfirms = bool.fromEnvironment('DOD_TEST_MODE');

  @override
  State<HoldSquare> createState() => _HoldSquareState();
}

class _HoldSquareState extends State<HoldSquare>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.holdFor)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && !_done) {
        _done = true;
        HapticFeedback.mediumImpact();
        widget.onConfirmed();
      }
    });
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Semantics(
      container: true,
      button: true,
      label: widget.semanticLabel,
      onTap: HoldSquare._clickConfirms
          ? () {
              if (_done) return;
              _done = true;
              widget.onConfirmed();
            }
          : null,
      child: Listener(
        onPointerDown: (_) {
          if (_done) return;
          HapticFeedback.lightImpact();
          _c.forward();
        },
        onPointerUp: (_) {
          if (!_done) {
            _c.animateBack(0, duration: const Duration(milliseconds: 200));
          }
        },
        onPointerCancel: (_) {
          if (!_done) {
            _c.animateBack(0, duration: const Duration(milliseconds: 200));
          }
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(
                color: p.sys.withValues(alpha: .55),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: _c.value,
                    widthFactor: 1,
                    child: ColoredBox(color: p.sys.withValues(alpha: .55)),
                  ),
                ),
                if (_c.value == 0)
                  Center(
                    child: ExcludeSemantics(
                      child: Text(
                        'HOLD',
                        style: Hud.mono(9, p.dim, spacing: .12),
                      ),
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

/// XP bar: solid current XP, striped gold for a reward still pending.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.xp,
    required this.max,
    this.pending = 0,
    this.height = 6,
  });

  final int xp;
  final int max;
  final int pending;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _XpPainter(
          cur: max == 0 ? 0 : (xp / max).clamp(0, 1),
          pend: max == 0 ? 0 : (pending / max).clamp(0, 1),
          color: p.sys,
        ),
      ),
    );
  }
}

class _XpPainter extends CustomPainter {
  _XpPainter({required this.cur, required this.pend, required this.color});
  final double cur;
  final double pend;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0x337D8BA8));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width * cur, s.height),
      Paint()..color = color,
    );
    final w = s.width * min(pend, 1 - cur);
    if (w <= 0) return;
    final r = Rect.fromLTWH(s.width * cur, 0, w, s.height);
    canvas.save();
    canvas.clipRect(r);
    canvas.drawRect(r, Paint()..color = Hud.gold.withValues(alpha: .35));
    final stripe = Paint()
      ..color = Hud.gold.withValues(alpha: .85)
      ..strokeWidth = 3;
    for (var x = r.left - s.height; x < r.right + s.height; x += 8) {
      canvas.drawLine(Offset(x, s.height), Offset(x + s.height, 0), stripe);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_XpPainter old) =>
      old.cur != cur || old.pend != pend || old.color != color;
}

/// Nav icons from the prototypes: quest diamond, status bars, penalty sign.
class NavIcon extends StatelessWidget {
  const NavIcon(this.kind, {super.key, required this.color});
  final int kind;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(20, 20), painter: _NavPainter(kind, color));
}

class _NavPainter extends CustomPainter {
  _NavPainter(this.kind, this.color);
  final int kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    switch (kind) {
      case 0:
        canvas.drawPath(
          Path()
            ..moveTo(10, 2)
            ..lineTo(18, 10)
            ..lineTo(10, 18)
            ..lineTo(2, 10)
            ..close(),
          p,
        );
        canvas.drawLine(const Offset(7, 10), const Offset(13, 10), p);
      case 1:
        canvas
          ..drawLine(const Offset(4, 16), const Offset(4, 10), p)
          ..drawLine(const Offset(10, 16), const Offset(10, 4), p)
          ..drawLine(const Offset(16, 16), const Offset(16, 8), p);
      default:
        canvas.drawPath(
          Path()
            ..moveTo(10, 2)
            ..lineTo(19, 17)
            ..lineTo(1, 17)
            ..close(),
          p,
        );
        canvas
          ..drawLine(const Offset(10, 8), const Offset(10, 12), p)
          ..drawLine(const Offset(10, 14), const Offset(10, 15), p);
    }
  }

  @override
  bool shouldRepaint(_NavPainter old) => old.color != color || old.kind != kind;
}

/// A small chamfered panel with corner brackets, used across Status and
/// Penalty (the prototypes' ".pnl").
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) =>
      HudFrame(chamfer: 10, padding: padding, child: child);
}

/// A tiny uppercase label (".kicker").
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Hud.mono(10, color ?? HudScope.of(context).dim, spacing: .22),
  );
}
