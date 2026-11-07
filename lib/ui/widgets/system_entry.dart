import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/system_catalogue.dart';
import '../../domain/systems.dart';
import '../theme.dart';
import 'system_sigil.dart';

/// Plays the System entry over the current screen and returns when it ends
/// (about 2.6 s, or at the first tap).
Future<void> showSystemEntry(BuildContext context, SystemKind kind) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => SystemEntry(kind: kind),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );

/// The chosen System's avatar is drawn in from the bottom, line by line,
/// behind an expanding ring; then "[ NAME ]" and "BOUND." appear.
///
/// 0-1200 ms scan reveal · 300-1500 ms ring burst · 1300 ms title ·
/// 1900 ms "BOUND." · 2600 ms close.
class SystemEntry extends StatefulWidget {
  const SystemEntry({super.key, required this.kind});
  final SystemKind kind;

  @override
  State<SystemEntry> createState() => _SystemEntryState();
}

class _SystemEntryState extends State<SystemEntry>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _c.forward().whenComplete(_close);
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double from, double to) =>
      ((_c.value * 2600 - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final aura = systemAura(widget.kind);
    final name = systemCatalogue[widget.kind]!.name.toUpperCase();
    return Semantics(
      container: true,
      button: true,
      label: '$name bound. Tap to continue',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: ColoredBox(
          color: const Color(0xFF05070D),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final reveal = Curves.easeOut.transform(_seg(0, 1200));
              final ring = _seg(300, 1500);
              final title = _seg(1300, 1700);
              final bound = _seg(1900, 2150);
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EntryPainter(aura, ring, reveal),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, -.25),
                    child: FractionallySizedBox(
                      widthFactor: .78,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: max(reveal, .001),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ExcludeSemantics(
                                child: SystemSigil(
                                  look: systemLook(widget.kind),
                                  interactive: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, .62),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: title,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - title)),
                            child: FittedBox(
                              child: Text(
                                '[ $name ]',
                                style: Hud.head(22, Colors.white).copyWith(
                                  shadows: [
                                    Shadow(color: aura, blurRadius: 14),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: bound,
                          child: Text(
                            'BOUND.',
                            style: Hud.mono(13, aura, spacing: .4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Scanlines across the reveal edge and an expanding ring.
class _EntryPainter extends CustomPainter {
  _EntryPainter(this.color, this.ring, this.reveal);
  final Color color;
  final double ring;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * .36);
    if (ring > 0 && ring < 1) {
      canvas.drawCircle(
        c,
        size.width * (.15 + .8 * Curves.easeOut.transform(ring)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - ring) + .5
          ..color = color.withValues(alpha: .8 * (1 - ring)),
      );
    }
    // The scan edge: a bright line where the figure is being drawn in.
    if (reveal > 0 && reveal < 1) {
      final box = size.width * .78;
      final top = size.height * .375 - box / 2;
      final y = top + box * (1 - reveal);
      canvas.drawRect(
        Rect.fromLTWH(0, y - 1, size.width, 2),
        Paint()..color = color.withValues(alpha: .9),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, y - 24, size.width, 24),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, y - 24, size.width, 24)),
      );
    }
    final lines = Paint()..color = color.withValues(alpha: .04);
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), lines);
    }
  }

  @override
  bool shouldRepaint(_EntryPainter o) => o.ring != ring || o.reveal != reveal;
}
