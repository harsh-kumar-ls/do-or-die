import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/systems.dart';
import '../game_model.dart';
import '../theme.dart';

/// How the Player is drawn: which System's gear, the glow colour, and an
/// optional tint over the body (red in a Penalty Zone).
///
/// The art is original (design/avatars/player): a body layer, a glow layer
/// the app tints and pulses, and one gear layer plus glow per System.
class AvatarLook {
  const AvatarLook({
    required this.glow,
    this.gear,
    this.tint,
    this.glitch = false,
  });

  final Color glow;
  final SystemKind? gear;
  final Color? tint;

  /// A short glitch twice per loop (Penalty Zone).
  final bool glitch;
}

/// Each System's colour.
Color systemAura(SystemKind k) => switch (k) {
  SystemKind.fitness => const Color(0xFF4FB3FF),
  SystemKind.personality => const Color(0xFFB07CFF),
  SystemKind.focus => const Color(0xFF5BD69A),
};

/// A System's look on its card and entry screen.
AvatarLook systemLook(SystemKind k) => AvatarLook(glow: systemAura(k), gear: k);

/// The Player today: the active System's gear; red and glitching in a
/// Penalty Zone, crimson in a Dungeon Penalty, gold on a Dungeon floor,
/// otherwise the System's colour.
AvatarLook playerLook(GameModel m) {
  final gear = m.systems?.progress.active;
  if (m.inPenalty) {
    final red = m.dungeonPenalty
        ? const Color(0xFFD7263D)
        : const Color(0xFFFF3B4A);
    return AvatarLook(glow: red, gear: gear, tint: red, glitch: true);
  }
  if (m.floorToday > 0) return AvatarLook(glow: Hud.gold, gear: gear);
  return AvatarLook(
    glow: gear == null ? Hud.rankColor(m.rank) : systemAura(gear),
    gear: gear,
  );
}

const _dir = 'assets/avatars/player';

/// A living avatar: it breathes, its glow pulses, an aura and rising motes
/// sit behind it, it leans toward a dragging finger and springs back, and a
/// tap flares the glow and calls [onTap].
///
/// Motion stops when the platform asks for reduced animations.
class PlayerAvatar extends StatefulWidget {
  const PlayerAvatar({
    super.key,
    required this.look,
    this.onTap,
    this.semanticLabel = 'Player avatar',
    this.interactive = true,
  });

  final AvatarLook look;
  final VoidCallback? onTap;
  final String semanticLabel;

  /// False inside something that handles its own taps and swipes (a flip
  /// card in a carousel): the avatar then only animates.
  final bool interactive;

  @override
  State<PlayerAvatar> createState() => _PlayerAvatarState();
}

class _PlayerAvatarState extends State<PlayerAvatar>
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

  /// A glow layer: a blurred halo under a sharp copy, both in [c].
  Widget _glow(String file, Color c, double strength) {
    final svg = SvgPicture.asset(
      '$_dir/$file',
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
    final blur = 2.5 + 3 * strength;
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Opacity(
            opacity: (.6 + .4 * strength).clamp(0.0, 1.0),
            child: svg,
          ),
        ),
        Opacity(opacity: (.75 + .25 * strength).clamp(0.0, 1.0), child: svg),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final gear = look.gear?.name;
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
                final strength = .35 * breath + flare;
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
                          -3 * breath,
                          0,
                          1,
                        )
                        ..rotateY(tilt.dx * .55)
                        ..rotateX(-tilt.dy * .35)
                        ..scaleByDouble(
                          1 + .012 * breath,
                          1 + .012 * breath,
                          1,
                          1,
                        ),
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, .8, 1],
                        ).createShader(r),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SvgPicture.asset(
                              '$_dir/base.svg',
                              colorFilter: look.tint == null
                                  ? null
                                  : ColorFilter.mode(
                                      look.tint!.withValues(
                                        alpha: glitch ? .45 : .16,
                                      ),
                                      BlendMode.srcATop,
                                    ),
                            ),
                            _glow('glow.svg', look.glow, strength),
                            if (gear != null) ...[
                              SvgPicture.asset('$_dir/$gear.svg'),
                              _glow('${gear}_glow.svg', look.glow, strength),
                            ],
                          ],
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

/// A soft glow behind the head that breathes and flares on tap, with a
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
    final c = Offset(size.width / 2, size.height * .40);
    final r = size.shortestSide * (.44 + .04 * breath + .12 * flare);
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
      ..color = color.withValues(alpha: .22 + .2 * flare);
    final rr = size.shortestSide * .42;
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

/// Small motes drifting upward past the figure.
class _MotesPainter extends CustomPainter {
  _MotesPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var i = 0; i < 14; i++) {
      final seed = (i * 0.618034) % 1;
      final phase = (t * (0.8 + seed * .6) + seed) % 1;
      final x =
          size.width * (.08 + .84 * ((i * 0.381966) % 1)) +
          sin((phase + seed) * 2 * pi) * 6;
      final y = size.height * (1 - phase);
      p.color = color.withValues(alpha: .5 * sin(phase * pi));
      canvas.drawCircle(Offset(x, y), 1 + 1.4 * seed, p);
    }
  }

  @override
  bool shouldRepaint(_MotesPainter o) => o.t != t || o.color != color;
}
