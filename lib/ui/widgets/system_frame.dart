import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Chamfered System window with a gradient edge and corner brackets, as in
/// the Claude Design Awakening (design/claude-design/awakening.html).
class HudFrame extends StatelessWidget {
  const HudFrame({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
    this.chamfer = 12,
    this.expand = false,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  final double chamfer;

  /// Fill the height the parent gives, with [child] taking the rest.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(
            title!,
            textAlign: TextAlign.center,
            style: Hud.head(
              13,
              p.hi,
              spacing: .26,
            ).copyWith(shadows: p.textGlow(.8)),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            color: p.sys.withValues(alpha: .18),
          ),
        ],
        if (expand) Expanded(child: child) else child,
      ],
    );
    return CustomPaint(
      foregroundPainter: _BracketPainter(p.hi),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: p.sys.withValues(alpha: .18), blurRadius: 14),
          ],
        ),
        child: ClipPath(
          clipper: ChamferClipper(chamfer),
          child: CustomPaint(
            painter: _EdgePainter(p, chamfer),
            child: Padding(padding: padding, child: content),
          ),
        ),
      ),
    );
  }
}

/// Clips a rectangle with all four corners cut at 45 degrees.
class ChamferClipper extends CustomClipper<Path> {
  const ChamferClipper(this.c, {this.corners = const [true, true, true, true]});

  final double c;

  /// Top-left, top-right, bottom-right, bottom-left.
  final List<bool> corners;

  @override
  Path getClip(Size s) => chamferPath(s, c, corners);

  @override
  bool shouldReclip(ChamferClipper old) => old.c != c;
}

Path chamferPath(
  Size s,
  double c, [
  List<bool> k = const [true, true, true, true],
]) {
  final tl = k[0] ? c : 0.0, tr = k[1] ? c : 0.0;
  final br = k[2] ? c : 0.0, bl = k[3] ? c : 0.0;
  return Path()
    ..moveTo(tl, 0)
    ..lineTo(s.width - tr, 0)
    ..lineTo(s.width, tr)
    ..lineTo(s.width, s.height - br)
    ..lineTo(s.width - br, s.height)
    ..lineTo(bl, s.height)
    ..lineTo(0, s.height - bl)
    ..lineTo(0, tl)
    ..close();
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.p, this.c);
  final HudPalette p;
  final double c;

  @override
  void paint(Canvas canvas, Size size) {
    final path = chamferPath(size, c);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF50D182E), Color(0xF5080E1B)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.sys,
            p.sys.withValues(alpha: .25),
            p.sys.withValues(alpha: .6),
          ],
          stops: const [0, .4, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.p != p;
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    const l = 14.0, o = -5.0;
    final paint = Paint()
      ..color = color.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    void corner(double x, double y, double dx, double dy) => canvas.drawPath(
      Path()
        ..moveTo(x, y + dy * l)
        ..lineTo(x, y)
        ..lineTo(x + dx * l, y),
      paint,
    );
    corner(o, o, 1, 1);
    corner(s.width - o, o, -1, 1);
    corner(o, s.height - o, 1, -1);
    corner(s.width - o, s.height - o, -1, -1);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

/// Primary button with one chamfered corner pair, glowing label, and a
/// press scale of 0.97.
class CutButton extends StatefulWidget {
  const CutButton(this.label, {super.key, this.onPressed, this.danger = false});

  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  State<CutButton> createState() => _CutButtonState();
}

class _CutButtonState extends State<CutButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final on = widget.onPressed != null;
    final edge = widget.danger ? Hud.warn : p.sys;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.label,
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
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: on ? 1 : .35,
            duration: const Duration(milliseconds: 200),
            child: _CutBox(
              edge: on ? edge : p.sys.withValues(alpha: .18),
              fill: edge.withValues(alpha: _down ? .18 : .08),
              child: ExcludeSemantics(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: Hud.head(
                    15,
                    widget.danger ? const Color(0xFFFFD6DA) : p.hi,
                    spacing: .28,
                  ).copyWith(shadows: p.textGlow(.8)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CutBox extends StatelessWidget {
  const _CutBox({
    required this.edge,
    required this.fill,
    required this.child,
    this.overlay,
  });

  final Color edge;
  final Color fill;
  final Widget child;
  final Widget? overlay;

  static const _corners = [true, false, true, false];

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const ChamferClipper(10, corners: _corners),
    child: CustomPaint(
      painter: _CutPainter(edge, fill),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (overlay != null) Positioned.fill(child: overlay!),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: child,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CutPainter extends CustomPainter {
  _CutPainter(this.edge, this.fill);
  final Color edge;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = chamferPath(size, 10, _CutBox._corners);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CutPainter old) => old.edge != edge || old.fill != fill;
}

/// Hold to confirm: a charge bar fills under the label over [holdFor]
/// (1 s), draining in 200 ms if released early. Test builds
/// (`DOD_TEST_MODE`) also accept a click, because the browser test agent
/// can't hold.
class ChargeButton extends StatefulWidget {
  const ChargeButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.enabled = true,
    this.danger = false,
    this.holdFor = const Duration(milliseconds: 1000),
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool enabled;
  final bool danger;
  final Duration holdFor;

  static const _clickConfirms = bool.fromEnvironment('DOD_TEST_MODE');

  @override
  State<ChargeButton> createState() => _ChargeButtonState();
}

class _ChargeButtonState extends State<ChargeButton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.holdFor)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && !_done) {
        _done = true;
        HapticFeedback.heavyImpact();
        setState(() {});
        widget.onConfirmed();
      }
    });
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled || _done) return;
    HapticFeedback.lightImpact();
    _c.forward();
  }

  void _stop() {
    if (_done || !_c.isAnimating) return;
    _c.animateBack(0, duration: const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final edge = widget.danger ? Hud.warn : p.sys;
    final fillColor = widget.danger ? const Color(0xFFFF3B4A) : p.sys;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      onTap: ChargeButton._clickConfirms && widget.enabled && !_done
          ? () {
              _done = true;
              widget.onConfirmed();
            }
          : null,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : .35,
          duration: const Duration(milliseconds: 200),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _CutBox(
              edge: widget.enabled ? edge : p.sys.withValues(alpha: .18),
              fill: edge.withValues(alpha: _done ? .22 : .08),
              overlay: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _done ? 1 : _c.value,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          fillColor.withValues(alpha: .15),
                          fillColor.withValues(alpha: .55),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    const SizedBox(width: 36),
                    Expanded(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: Hud.head(
                          15,
                          widget.danger ? const Color(0xFFFFD6DA) : p.hi,
                          spacing: .28,
                        ).copyWith(shadows: p.textGlow(.8)),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: _c.isAnimating
                          ? Text(
                              '${(_c.value * 100).round()}%',
                              style: Hud.mono(10, p.dim),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-screen white flash (320 ms) and a short shake, triggered by
/// [FlashController.flash] and [FlashController.shake].
class FlashController extends ChangeNotifier {
  int flashes = 0;
  int shakes = 0;

  void flash() {
    flashes++;
    notifyListeners();
  }

  void shake() {
    shakes++;
    notifyListeners();
  }
}

class FlashLayer extends StatefulWidget {
  const FlashLayer({super.key, required this.controller, required this.child});

  final FlashController controller;
  final Widget child;

  @override
  State<FlashLayer> createState() => _FlashLayerState();
}

class _FlashLayerState extends State<FlashLayer> with TickerProviderStateMixin {
  late final _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  int _f = 0, _s = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_on);
  }

  void _on() {
    if (widget.controller.flashes != _f) {
      _f = widget.controller.flashes;
      _flash.forward(from: 0);
    }
    if (widget.controller.shakes != _s) {
      _s = widget.controller.shakes;
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_on);
    _flash.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = t == 0 || t == 1
              ? 0.0
              : (t < .33
                    ? -3.0
                    : t < .66
                    ? 3.0
                    : -2.0);
          final dy = t == 0 || t == 1
              ? 0.0
              : (t < .33
                    ? 2.0
                    : t < .66
                    ? -2.0
                    : -1.0);
          return Transform.translate(offset: Offset(dx, dy), child: child);
        },
        child: widget.child,
      ),
      IgnorePointer(
        child: AnimatedBuilder(
          animation: _flash,
          builder: (context, _) {
            final t = _flash.value;
            final o = t == 0
                ? 0.0
                : (t < .15 ? t / .15 * .55 : .55 * (1 - (t - .15) / .85));
            return ColoredBox(
              color: const Color(0xFFCFEAFF).withValues(alpha: o),
            );
          },
        ),
      ),
    ],
  );
}

/// Calls [onTick] every [every] while mounted. Small helper for screens that
/// re-check permissions while visible.
class Poller {
  Poller(Duration every, VoidCallback onTick)
    : _t = Timer.periodic(every, (_) => onTick());
  final Timer _t;
  void cancel() => _t.cancel();
}
