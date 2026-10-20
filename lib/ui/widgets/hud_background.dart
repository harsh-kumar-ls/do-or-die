import 'package:flutter/material.dart';

import '../theme.dart';

/// Void background with a radial glow from the top, a faint grid and
/// scanlines, all scaled by the palette's intensity.
class HudBackground extends StatelessWidget {
  const HudBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1),
          radius: 1.3,
          colors: [p.top, p.voidColor],
          stops: const [0, .62],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: CustomPaint(painter: _GridPainter(p))),
          child,
          IgnorePointer(child: CustomPaint(painter: _ScanPainter(p))),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.p);
  final HudPalette p;
  static const step = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Fade the grid out towards the edges and bottom.
    canvas.saveLayer(rect, Paint());
    final line = Paint()
      ..color = p.sys.withValues(alpha: p.gridAlpha)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = const RadialGradient(
          center: Alignment(0, -.4),
          radius: .9,
          colors: [Colors.white, Colors.transparent],
          stops: [.3, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.p != p;
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.p);
  final HudPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    if (p.scanAlpha <= 0) return;
    final line = Paint()..color = Colors.white.withValues(alpha: p.scanAlpha);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), line);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.p != p;
}
