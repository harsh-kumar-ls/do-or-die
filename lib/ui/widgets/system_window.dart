import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme.dart';
import 'decode_text.dart';

/// The signature System window: chamfered panel, thin frame, corner brackets.
/// Powers on with a short vertical expand and flash.
class SystemWindow extends StatelessWidget {
  const SystemWindow({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.delay = Duration.zero,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 14),
    this.animate = true,
    this.expand = false,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final Duration delay;
  final EdgeInsets padding;
  final bool animate;

  /// Fill the height the parent gives, with [child] taking the remaining space.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    Widget body = CustomPaint(
      painter: _FramePainter(p),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (title != null) ...[
              WindowTitle(title!, delay: delay),
              Container(
                height: 1,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                color: p.sys.withValues(alpha: p.lineAlpha * .7),
              ),
            ],
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Hud.mono(11, p.dim),
                ),
              ),
            if (expand) Expanded(child: child) else child,
          ],
        ),
      ),
    );

    if (!animate || MediaQuery.of(context).disableAnimations) return body;
    return body
        .animate(delay: delay)
        .scaleY(
          begin: .04,
          end: 1,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
        )
        .fadeIn(duration: 160.ms)
        .then()
        .shimmer(duration: 500.ms, color: p.hi.withValues(alpha: .15));
  }
}

/// Window heading: decodes from random glyphs, glows, and glitches in the
/// Lockdown.
class WindowTitle extends StatelessWidget {
  const WindowTitle(
    this.text, {
    super.key,
    this.delay = Duration.zero,
    this.size = 14,
  });

  final String text;
  final Duration delay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final style = Hud.head(size, p.hi).copyWith(shadows: p.textGlow());
    Widget title = DecodeText(
      text,
      style: style,
      textAlign: TextAlign.center,
      delay: delay + 120.ms,
    );
    if (p.glitch && !MediaQuery.of(context).disableAnimations) {
      title = title
          .animate(onPlay: (c) => c.repeat())
          .then(delay: 2900.ms)
          .shakeX(hz: 18, amount: 2, duration: 160.ms)
          .tint(color: const Color(0xFF4FB3FF), end: .35, duration: 80.ms)
          .then()
          .tint(begin: .35, end: 0, duration: 80.ms);
    }
    return title;
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.p);

  final HudPalette p;
  static const cut = 10.0;
  static const bracket = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shape = Path()
      ..moveTo(0, cut)
      ..lineTo(cut, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - cut)
      ..lineTo(w - cut, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(shape, Paint()..color = p.panel);

    // Faint inner glow along the frame.
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = p.sys.withValues(alpha: p.glowAlpha * .12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.glow * .8),
    );

    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = p.line,
    );

    final b = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..color = p.sys;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = p.glowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.glow * .4);

    for (final paint in [glow, b]) {
      // Top-left follows the chamfer.
      canvas.drawPath(
        Path()
          ..moveTo(0, cut + bracket)
          ..lineTo(0, cut)
          ..lineTo(cut, 0)
          ..lineTo(cut + bracket, 0),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(w - bracket, 0)
          ..lineTo(w, 0)
          ..lineTo(w, bracket),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, h - bracket)
          ..lineTo(0, h)
          ..lineTo(bracket, h),
        paint,
      );
      // Bottom-right follows the chamfer.
      canvas.drawPath(
        Path()
          ..moveTo(w, h - cut - bracket)
          ..lineTo(w, h - cut)
          ..lineTo(w - cut, h)
          ..lineTo(w - cut - bracket, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.p != p;
}
