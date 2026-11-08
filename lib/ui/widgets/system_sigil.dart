import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/progression.dart';
import '../../domain/systems.dart';
import '../game_model.dart';
import '../theme.dart';
import 'awakening_art.dart';

/// How the sigil is drawn: which System's emblem, the glow colour, and an
/// optional tint (red in a Lockdown).
class SigilLook {
  const SigilLook({
    required this.glow,
    this.system,
    this.tint,
    this.glitch = false,
  });

  final Color glow;

  /// The System whose emblem is shown; the app emblem when null.
  final SystemKind? system;
  final Color? tint;

  /// A short glitch twice per loop (Lockdown).
  final bool glitch;
}

const dungeonRed = Color(0xFFD7263D);
const penaltyRed = Color(0xFFFF3B4A);

/// Each System's colour.
Color systemAura(SystemKind k) => switch (k) {
  SystemKind.fitness => const Color(0xFF4FB3FF),
  SystemKind.personality => const Color(0xFFB07CFF),
  SystemKind.focus => const Color(0xFF5BD69A),
};

/// A System's look on its card and entry screen.
SigilLook systemLook(SystemKind k) => SigilLook(glow: systemAura(k), system: k);

/// The Player's sigil today: the active System's emblem; red and glitching
/// in a Lockdown, crimson in a Dungeon Penalty, gold on a Dungeon floor,
/// otherwise the System's colour.
SigilLook playerLook(GameModel m) {
  final system = m.systems?.progress.active;
  if (m.inPenalty) {
    final red = m.dungeonPenalty ? dungeonRed : penaltyRed;
    return SigilLook(glow: red, system: system, tint: red, glitch: true);
  }
  if (m.floorToday > 0) return SigilLook(glow: Hud.gold, system: system);
  return SigilLook(
    glow: system == null ? Hud.rankColor(m.rank) : systemAura(system),
    system: system,
  );
}

/// The active System's emblem, alive: it breathes, its glow pulses, an aura
/// and rising motes sit behind it, it leans toward a dragging finger and
/// springs back, and a tap flares the glow and calls [onTap]. With [rank]
/// set, the rank hexagon sits on its lower right.
///
/// Motion stops when the platform asks for reduced animations.
class SystemSigil extends StatefulWidget {
  const SystemSigil({
    super.key,
    required this.look,
    this.rank,
    this.onTap,
    this.semanticLabel = 'System sigil',
    this.interactive = true,
  });

  final SigilLook look;

  /// Shown as a small hexagon badge when set.
  final Rank? rank;
  final VoidCallback? onTap;
  final String semanticLabel;

  /// False inside something that handles its own taps and swipes (a flip
  /// card in a carousel): the sigil then only animates.
  final bool interactive;

  @override
  State<SystemSigil> createState() => _SystemSigilState();
}

class _SystemSigilState extends State<SystemSigil>
    with TickerProviderStateMixin {
  // One slow loop drives breathing, the glow pulse, motes and glitches.
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  late final _flare = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  Offset _tilt = Offset.zero;
  Offset _released = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _flare.dispose();
    _spring.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d, Size size) {
    _spring
      ..stop()
      ..value = 0;
    setState(() {
      _tilt = Offset(
        (_tilt.dx + d.delta.dx / size.width).clamp(-.5, .5),
        (_tilt.dy + d.delta.dy / size.height).clamp(-.5, .5),
      );
    });
  }

  void _release() {
    _released = _tilt;
    _tilt = Offset.zero;
    _spring
      ..value = 0
      ..animateTo(1, curve: Curves.elasticOut);
  }

  void _tap() {
    HapticFeedback.lightImpact();
    _flare.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return Semantics(
          container: true,
          button: widget.interactive && widget.onTap != null,
          label: widget.semanticLabel,
          child: GestureDetector(
            behavior: widget.interactive
                ? HitTestBehavior.opaque
                : HitTestBehavior.translucent,
            onTap: widget.interactive ? _tap : null,
            onPanUpdate: widget.interactive ? (d) => _drag(d, size) : null,
            onPanEnd: widget.interactive ? (_) => _release() : null,
            onPanCancel: widget.interactive ? _release : null,
            child: AnimatedBuilder(
              animation: Listenable.merge([_loop, _flare, _spring]),
              builder: (context, _) {
                final t = _loop.value;
                final breath = sin(t * 2 * pi * 2) * .5 + .5; // 3 s breaths
                final tilt = _spring.value > 0
                    ? Offset.lerp(_released, Offset.zero, _spring.value)!
                    : _tilt;
                final flare = _flare.isAnimating
                    ? Curves.easeOut.transform(1 - _flare.value)
                    : 0.0;
                final glitch =
                    look.glitch &&
                    ((t > .31 && t < .335) || (t > .78 && t < .80));
                final emblem = CustomPaint(
                  painter: look.system == null
                      ? EmblemPainter(glow: 1 + .6 * breath + flare)
                      : SystemEmblemPainter(look.system!, t * 6),
                );
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _AuraPainter(
                        color: look.glow,
                        t: t,
                        breath: breath,
                        flare: flare,
                      ),
                    ),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .0015)
                        ..translateByDouble(
                          glitch ? (t * 997 % 1 - .5) * 10 : 0,
                          -2 * breath,
                          0,
                          1,
                        )
                        ..rotateY(tilt.dx * .55)
                        ..rotateX(-tilt.dy * .35)
                        ..scaleByDouble(
                          1 + .02 * breath + .06 * flare,
                          1 + .02 * breath + .06 * flare,
                          1,
                          1,
                        ),
                      child: Padding(
                        padding: EdgeInsets.all(size.shortestSide * .08),
                        child: look.tint == null
                            ? emblem
                            : ColorFiltered(
                                colorFilter: ColorFilter.mode(
                                  look.tint!,
                                  BlendMode.srcATop,
                                ),
                                child: Opacity(
                                  opacity: glitch ? .6 : 1,
                                  child: emblem,
                                ),
                              ),
                      ),
                    ),
                    if (widget.rank != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: size.shortestSide * .32,
                        height: size.shortestSide * .34,
                        child: IgnorePointer(
                          child: Semantics(
                            label: 'Rank ${widget.rank!.name.toUpperCase()}',
                            child: CustomPaint(
                              painter: RankHexPainter(widget.rank!),
                            ),
                          ),
                        ),
                      ),
                    if (!MediaQuery.disableAnimationsOf(context))
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _MotesPainter(color: look.glow, t: t),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// A soft glow behind the emblem that breathes and flares on tap, with a
/// thin broken ring turning slowly.
class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.color,
    required this.t,
    required this.breath,
    required this.flare,
  });

  final Color color;
  final double t;
  final double breath;
  final double flare;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * (.48 + .04 * breath + .1 * flare);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .22 + .08 * breath + .3 * flare),
            color.withValues(alpha: .06),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: .25 + .2 * flare);
    final rr = size.shortestSide * .47;
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rr),
        t * 2 * pi + i * 2 * pi / 3,
        pi / 2.4,
        false,
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter o) =>
      o.t != t || o.flare != flare || o.color != color;
}

/// Small motes drifting upward past the emblem.
class _MotesPainter extends CustomPainter {
  _MotesPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var i = 0; i < 12; i++) {
      final seed = (i * 0.618034) % 1;
      final phase = (t * (0.8 + seed * .6) + seed) % 1;
      final x =
          size.width * (.1 + .8 * ((i * 0.381966) % 1)) +
          sin((phase + seed) * 2 * pi) * 5;
      final y = size.height * (1 - phase);
      p.color = color.withValues(alpha: .5 * sin(phase * pi));
      canvas.drawCircle(Offset(x, y), 1 + 1.2 * seed, p);
    }
  }

  @override
  bool shouldRepaint(_MotesPainter o) => o.t != t || o.color != color;
}
