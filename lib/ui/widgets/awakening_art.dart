import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/progression.dart';
import '../../domain/systems.dart';
import '../theme.dart';

/// Original line-art from the Claude Design Awakening
/// (design/claude-design/awakening.html), drawn in code.

const _sys = Color(0xFF4FB3FF);
const _hi = Color(0xFFA9DCFF);

/// The Awakening emblem: nested diamonds with axis ticks (160 x 160).
class EmblemPainter extends CustomPainter {
  const EmblemPainter({this.glow = 1});

  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 160;
    canvas.scale(k);
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 3 * glow);
    Path diamond(double r) => Path()
      ..moveTo(80, 80 - r)
      ..lineTo(80 + r, 80)
      ..lineTo(80, 80 + r)
      ..lineTo(80 - r, 80)
      ..close();
    canvas.drawPath(diamond(64), stroke(_sys, 2));
    canvas.drawPath(diamond(38), stroke(_hi, 2));
    final ticks = stroke(_sys, 1.5);
    canvas
      ..drawLine(const Offset(80, 2), const Offset(80, 30), ticks)
      ..drawLine(const Offset(80, 130), const Offset(80, 158), ticks)
      ..drawLine(const Offset(2, 80), const Offset(22, 80), ticks)
      ..drawLine(const Offset(138, 80), const Offset(158, 80), ticks);
    final thin = stroke(_hi, 1);
    canvas
      ..drawLine(const Offset(80, 50), const Offset(80, 64), thin)
      ..drawLine(const Offset(80, 96), const Offset(80, 110), thin);
    canvas.drawPath(
      Path()
        ..moveTo(72, 80)
        ..lineTo(80, 72)
        ..lineTo(88, 80)
        ..lineTo(80, 88)
        ..close(),
      Paint()..color = _hi,
    );
  }

  @override
  bool shouldRepaint(EmblemPainter old) => old.glow != glow;
}

/// A System's glyph inside a diamond (64 x 64).
class SystemGlyphPainter extends CustomPainter {
  const SystemGlyphPainter(this.kind, {this.lit = false});

  final SystemKind kind;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    final p = Paint()
      ..color = lit ? _hi : _sys
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = lit ? const MaskFilter.blur(BlurStyle.solid, 3) : null;
    canvas.drawPath(
      Path()
        ..moveTo(32, 4)
        ..lineTo(60, 32)
        ..lineTo(32, 60)
        ..lineTo(4, 32)
        ..close(),
      p,
    );
    switch (kind) {
      case SystemKind.fitness:
        canvas
          ..drawLine(const Offset(18, 32), const Offset(46, 32), p)
          ..drawLine(const Offset(22, 25), const Offset(22, 39), p)
          ..drawLine(const Offset(42, 25), const Offset(42, 39), p)
          ..drawLine(const Offset(14, 28), const Offset(14, 36), p)
          ..drawLine(const Offset(50, 28), const Offset(50, 36), p);
      case SystemKind.personality:
        canvas.drawPath(
          Path()
            ..moveTo(20, 24)
            ..lineTo(44, 24)
            ..lineTo(44, 36)
            ..lineTo(30, 36)
            ..lineTo(24, 42)
            ..lineTo(24, 36)
            ..lineTo(20, 36)
            ..close(),
          p,
        );
        canvas.drawLine(
          const Offset(26, 30),
          const Offset(38, 30),
          p..strokeWidth = 1.5,
        );
      case SystemKind.focus:
        canvas
          ..drawCircle(const Offset(32, 32), 11, p)
          ..drawCircle(
            const Offset(32, 32),
            3,
            Paint()..color = lit ? _hi : _sys,
          )
          ..drawLine(const Offset(32, 14), const Offset(32, 20), p)
          ..drawLine(const Offset(32, 44), const Offset(32, 50), p)
          ..drawLine(const Offset(14, 32), const Offset(20, 32), p)
          ..drawLine(const Offset(44, 32), const Offset(50, 32), p);
    }
  }

  @override
  bool shouldRepaint(SystemGlyphPainter old) =>
      old.kind != kind || old.lit != lit;
}

/// The hexagonal rank badge (116 x 124), letter and colour per rank, with
/// an optional shock ring that grows and fades ([ring] 0..1).
class RankHexPainter extends CustomPainter {
  const RankHexPainter(this.rank, {this.ring = 0});

  final Rank rank;
  final double ring;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 116);
    final c = Hud.rankColor(rank);
    Path hex(double t) => Path()
      ..moveTo(58, 2 + t)
      ..lineTo(112 - t, 32 + t / 2)
      ..lineTo(112 - t, 92 - t / 2)
      ..lineTo(58, 122 - t)
      ..lineTo(4 + t, 92 - t / 2)
      ..lineTo(4 + t, 32 + t / 2)
      ..close();
    if (ring > 0 && ring < 1) {
      canvas.save();
      canvas.translate(58, 62);
      canvas.scale(1 + .8 * ring);
      canvas.translate(-58, -62);
      canvas.drawPath(
        hex(0),
        Paint()
          ..color = c.withValues(alpha: .9 * (1 - ring))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.restore();
    }
    canvas.drawPath(hex(4), Paint()..color = const Color(0xE60A1222));
    canvas.drawPath(
      hex(4),
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
    canvas.drawPath(
      hex(16),
      Paint()
        ..color = c.withValues(alpha: .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: rank.name.toUpperCase(),
        style: Hud.head(50, c, spacing: 0).copyWith(
          shadows: [Shadow(color: c.withValues(alpha: .7), blurRadius: 12)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(58 - tp.width / 2, 62 - tp.height / 2));
  }

  @override
  bool shouldRepaint(RankHexPainter old) =>
      old.rank != rank || old.ring != ring;
}

/// Particles that converge from a random ring onto the emblem's outline
/// over [t] 0..1 (each with its own delay), centred at [target].
class ParticlePainter extends CustomPainter {
  ParticlePainter(this.t, this.target, this.particles);

  final double t;
  final Offset target;
  final List<Particle> particles;

  static List<Particle> make(Random r) {
    final targets = <Offset>[];
    void diamond(double rad, int n) {
      const corners = [
        Offset(0, -1),
        Offset(1, 0),
        Offset(0, 1),
        Offset(-1, 0),
        Offset(0, -1),
      ];
      for (var i = 0; i < n; i++) {
        final u = i / n * 4, s = u.floor(), f = u - s;
        targets.add((corners[s] + (corners[s + 1] - corners[s]) * f) * rad);
      }
    }

    diamond(64, 72);
    diamond(38, 44);
    for (var i = 0; i < 10; i++) {
      targets
        ..add(Offset(0, -78 + i * 2.8))
        ..add(Offset(0, 52 + i * 2.8));
    }
    for (var i = 0; i < 8; i++) {
      targets
        ..add(Offset(-78 + i * 2.5, 0))
        ..add(Offset(58 + i * 2.5, 0));
    }
    return [
      for (final to in targets)
        Particle(
          from:
              Offset.fromDirection(
                r.nextDouble() * 2 * pi,
                220 + r.nextDouble() * 260,
              ) +
              const Offset(0, 190),
          to: to,
          delay: r.nextDouble() * .27,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    double ease(double x) =>
        x < .5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2;
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    for (final p in particles) {
      final k = ((t - p.delay) / (1 - .27)).clamp(0.0, 1.0);
      final e = ease(k);
      final pos = target + p.from + (p.to - p.from) * e;
      paint.color = k > .95 ? _hi : _sys.withValues(alpha: .3 + .7 * e);
      canvas.drawRect(Rect.fromCenter(center: pos, width: 2, height: 2), paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => old.t != t;
}

class Particle {
  const Particle({required this.from, required this.to, required this.delay});
  final Offset from;
  final Offset to;
  final double delay;
}

/// The 24-hour rest ring: drag the moon (sleep) and sun (wake) handles.
/// Minutes snap to 15. Rest must be 4 to 10 hours.
class RestRing extends StatefulWidget {
  const RestRing({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
  });

  /// Minutes after midnight.
  final int start;
  final int end;
  final void Function(int start, int end) onChanged;

  static int restMinutes(int start, int end) => (end - start + 1440) % 1440;

  /// Null when the rest period is allowed, else why not.
  static String? problem(int start, int end) {
    final d = restMinutes(start, end);
    if (d > 600) return 'MAXIMUM REST IS 10 H';
    if (d < 240) return 'MINIMUM REST IS 4 H';
    return null;
  }

  @override
  State<RestRing> createState() => _RestRingState();
}

class _RestRingState extends State<RestRing> {
  bool? _draggingStart;

  Offset _pt(int m, double r, Offset c) {
    final a = m / 1440 * 2 * pi;
    return c + Offset(sin(a) * r, -cos(a) * r);
  }

  int _toMin(Offset pos, Offset c) {
    final v = pos - c;
    var a = atan2(v.dx, -v.dy);
    if (a < 0) a += 2 * pi;
    return (a / (2 * pi) * 1440 / 15).round() * 15 % 1440;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, cons) {
      final side = min(cons.maxWidth, cons.maxHeight);
      final r = side * 120 / 330;
      final c = Offset(cons.maxWidth / 2, cons.maxHeight / 2);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          final s = (d.localPosition - _pt(widget.start, r, c)).distance;
          final e = (d.localPosition - _pt(widget.end, r, c)).distance;
          _draggingStart = min(s, e) > side * .12 ? null : s <= e;
        },
        onPanUpdate: (d) {
          final which = _draggingStart;
          if (which == null) return;
          final m = _toMin(d.localPosition, c);
          if (which && m != widget.start) widget.onChanged(m, widget.end);
          if (!which && m != widget.end) widget.onChanged(widget.start, m);
        },
        onPanEnd: (_) => _draggingStart = null,
        child: CustomPaint(
          size: Size(cons.maxWidth, cons.maxHeight),
          painter: _RingPainter(
            widget.start,
            widget.end,
            r,
            c,
            RestRing.problem(widget.start, widget.end) != null,
          ),
        ),
      );
    },
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.s, this.e, this.r, this.c, this.bad);
  final int s, e;
  final double r;
  final Offset c;
  final bool bad;

  Offset _pt(int m, double rad) {
    final a = m / 1440 * 2 * pi;
    return c + Offset(sin(a) * rad, -cos(a) * rad);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = r / 120;
    for (var i = 0; i < 96; i++) {
      final big = i % 12 == 0, mid = i % 4 == 0;
      final m = i * 15;
      final r1 = r + 18 * k,
          r2 =
              r1 +
              (big
                      ? 10
                      : mid
                      ? 6
                      : 3) *
                  k;
      canvas.drawLine(
        _pt(m, r1),
        _pt(m, r2),
        Paint()
          ..color = big ? _hi : const Color(0x807D8BA8)
          ..strokeWidth = big ? 1.5 : 1,
      );
    }
    for (final h in const [0, 6, 12, 18]) {
      final tp = TextPainter(
        text: TextSpan(
          text: h.toString().padLeft(2, '0'),
          style: Hud.mono(11, const Color(0xFF7D8BA8)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        _pt(h * 60, r - 24 * k) - Offset(tp.width / 2, tp.height / 2),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = _sys.withValues(alpha: .15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26 * k,
    );
    final sweep = RestRing.restMinutes(s, e) / 1440 * 2 * pi;
    final startA = s / 1440 * 2 * pi - pi / 2;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      startA,
      sweep,
      false,
      Paint()
        ..color = (bad ? Hud.warn : _sys).withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26 * k,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r + 13 * k),
      startA,
      sweep,
      false,
      Paint()
        ..color = _hi
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    void handle(int m, Color col, bool moon) {
      final p = _pt(m, r);
      canvas.drawCircle(p, 15 * k, Paint()..color = const Color(0xFF05070D));
      canvas.drawCircle(
        p,
        15 * k,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (moon) {
        canvas.drawCircle(p, 6 * k, Paint()..color = col);
        canvas.drawCircle(
          p + Offset(3 * k, -2 * k),
          5 * k,
          Paint()..color = const Color(0xFF05070D),
        );
      } else {
        canvas.drawCircle(p, 4 * k, Paint()..color = col);
        final ray = Paint()
          ..color = col
          ..strokeWidth = 1.5;
        for (var i = 0; i < 4; i++) {
          final d = Offset.fromDirection(i * pi / 2, 8 * k);
          canvas.drawLine(p + d, p + d * 1.2, ray);
        }
      }
    }

    handle(s, _hi, true);
    handle(e, Hud.gold, false);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.s != s || old.e != e || old.r != r || old.bad != bad;
}

/// The three System emblems from the Claude Design carousel (200 x 200):
/// an outer dashed ring turning every 24 s, an inner ring 14 s the other
/// way, a pulsing core, and System-specific line art. [t] is seconds.
class SystemEmblemPainter extends CustomPainter {
  const SystemEmblemPainter(this.kind, this.t);

  final SystemKind kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    const c = Offset(100, 100);
    Paint line(Color col, double w, [double a = 1]) => Paint()
      ..color = col.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);
    void dashedCircle(double r, double dash, double gap, double turn, Paint p) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(turn * 2 * pi);
      for (var a = 0.0; a < 2 * pi; a += (dash + gap) / r) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          a,
          dash / r,
          false,
          p,
        );
      }
      canvas.restore();
    }

    final pulse = .5 + .5 * sin(t / 2.4 * 2 * pi);
    dashedCircle(88, 2, 7, t / 24, line(_sys, 1.5, .7));
    switch (kind) {
      case SystemKind.fitness:
        dashedCircle(74, 92, 24.2, -t / 14, line(_hi, 1.2, .6));
        final p = line(_sys, 3);
        canvas.drawPath(
          Path()
            ..moveTo(66, 108)
            ..cubicTo(58, 74, 72, 54, 100, 54)
            ..cubicTo(128, 54, 142, 74, 134, 108),
          p,
        );
        canvas.drawPath(
          Path()
            ..moveTo(80, 102)
            ..cubicTo(76, 80, 84, 68, 100, 68)
            ..cubicTo(116, 68, 124, 80, 120, 102),
          line(_sys, 1.2, .6),
        );
        final torso = Path()
          ..moveTo(74, 158)
          ..cubicTo(54, 146, 56, 108, 80, 100)
          ..lineTo(120, 100)
          ..cubicTo(144, 108, 146, 146, 126, 158)
          ..close();
        canvas.drawPath(torso, Paint()..color = _sys.withValues(alpha: .08));
        canvas.drawPath(torso, line(_sys, 2.5));
        canvas.drawPath(
          Path()
            ..moveTo(64, 130)
            ..lineTo(82, 130)
            ..lineTo(89, 116)
            ..lineTo(98, 144)
            ..lineTo(105, 122)
            ..lineTo(110, 130)
            ..lineTo(136, 130),
          line(_hi, 2),
        );
        canvas.drawCircle(
          const Offset(98, 144),
          3.5 * (1 + .35 * pulse),
          Paint()..color = _hi.withValues(alpha: 1 - .55 * pulse),
        );
        final side = line(_sys, 1.5, .55);
        canvas
          ..drawLine(const Offset(20, 118), const Offset(42, 118), side)
          ..drawLine(const Offset(26, 128), const Offset(42, 128), side)
          ..drawLine(const Offset(158, 118), const Offset(180, 118), side)
          ..drawLine(const Offset(158, 128), const Offset(174, 128), side);
      case SystemKind.personality:
        final left = Path()
          ..moveTo(100, 152)
          ..cubicTo(84, 142, 62, 140, 38, 144)
          ..lineTo(38, 100)
          ..cubicTo(62, 96, 84, 98, 100, 110)
          ..close();
        final right = Path()
          ..moveTo(100, 152)
          ..cubicTo(116, 142, 138, 140, 162, 144)
          ..lineTo(162, 100)
          ..cubicTo(138, 96, 116, 98, 100, 110)
          ..close();
        for (final pg in [left, right]) {
          canvas.drawPath(pg, Paint()..color = _sys.withValues(alpha: .08));
          canvas.drawPath(pg, line(_sys, 2));
        }
        final rule = line(_sys, 1, .55);
        for (final y in [112.0, 124.0, 136.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(48, y)
              ..cubicTo(62, y - 3, 78, y - 2, 90, y + 5),
            rule,
          );
        }
        for (final y in [117.0, 129.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(110, y)
              ..cubicTo(122, y - 7, 138, y - 8, 152, y - 5),
            rule,
          );
        }
        canvas.drawLine(
          const Offset(100, 108),
          const Offset(100, 84),
          line(_hi, 1.5),
        );
        const heights = [12, 26, 18, 40, 30, 44, 22, 14, 8];
        for (var k = 0; k < heights.length; k++) {
          final s = .35 + .65 * (.5 + .5 * cos((t + k * .12) / 1.4 * 2 * pi));
          final h = heights[k] * s;
          final x = 52.0 + k * 12;
          canvas.drawLine(
            Offset(x, 62 - h / 2),
            Offset(x, 62 + h / 2),
            line(_hi, 3),
          );
        }
        canvas.drawCircle(
          const Offset(100, 108),
          4.5 * (1 + .35 * pulse),
          Paint()..color = _hi.withValues(alpha: 1 - .55 * pulse),
        );
      case SystemKind.focus:
        final eye = Path()
          ..moveTo(18, 100)
          ..quadraticBezierTo(100, 30, 182, 100)
          ..quadraticBezierTo(100, 170, 18, 100)
          ..close();
        canvas.drawPath(eye, Paint()..color = _sys.withValues(alpha: .06));
        canvas.drawPath(eye, line(_sys, 2));
        dashedCircle(40, 18, 6.2, -t / 14, line(_hi, 1.2));
        dashedCircle(29, 2, 4, t / 9, line(_sys, 2));
        canvas.drawCircle(c, 18, line(_sys, 2));
        canvas.drawCircle(
          c,
          7 * (1 + .35 * pulse),
          Paint()..color = _hi.withValues(alpha: 1 - .55 * pulse),
        );
        final tick = line(_sys, 1.5, .7);
        canvas
          ..drawLine(const Offset(100, 4), const Offset(100, 22), tick)
          ..drawLine(const Offset(100, 178), const Offset(100, 196), tick)
          ..drawLine(const Offset(4, 100), const Offset(14, 100), tick)
          ..drawLine(const Offset(186, 100), const Offset(196, 100), tick);
    }
  }

  @override
  bool shouldRepaint(SystemEmblemPainter old) => old.t != t || old.kind != kind;
}
