import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../fx.dart';
import '../theme.dart';

/// Thin progress bar that glows; gold when complete.
class HudBar extends StatelessWidget {
  const HudBar({
    super.key,
    required this.value,
    this.height = 4,
    this.done = false,
  });

  final double value;
  final double height;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final color = done ? Hud.gold : p.sys;
    return Container(
      height: height,
      color: p.sys.withValues(alpha: .12),
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, c) => AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: c.maxWidth * value.clamp(0, 1),
          decoration: BoxDecoration(
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: p.glowAlpha),
                blurRadius: p.glow * .8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outlined System button.
class HudButton extends StatelessWidget {
  const HudButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.dense = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool dense;

  /// Spoken name when [label] is a symbol, e.g. "×".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final enabled = onPressed != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: _Pressable(
        onTap: enabled
            ? () {
                Fx.instance.play(Cue.tap);
                onPressed!();
              }
            : null,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: dense ? 6 : 9, horizontal: 8),
          decoration: BoxDecoration(
            color: p.sys.withValues(alpha: enabled ? .06 : .02),
            border: Border.all(
              color: p.sys.withValues(alpha: enabled ? p.lineAlpha + .05 : .12),
            ),
          ),
          alignment: Alignment.center,
          child: ExcludeSemantics(
            child: Text(
              label,
              style: Hud.mono(11, enabled ? p.hi : p.dim, spacing: .1),
            ),
          ),
        ),
      ),
    );
  }
}

/// A button that must be held to fire, so a stray tap can't complete a task.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.label,
    required this.doneLabel,
    required this.onConfirmed,
    this.done = false,
    this.holdFor = const Duration(milliseconds: 900),
  });

  final String label;
  final String doneLabel;
  final VoidCallback onConfirmed;
  final bool done;
  final Duration holdFor;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.holdFor,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed) {
      Fx.instance.play(Cue.confirm);
      widget.onConfirmed();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down() {
    if (widget.done) return;
    HapticFeedback.lightImpact();
    _c.forward(from: 0);
  }

  /// Set only for the web build that TestSprite drives
  /// (`--dart-define=DOD_TEST_MODE=true`): its browser agent can click but
  /// can't hold. Real builds never set it, so the hold is always required.
  static const _clickConfirms = bool.fromEnvironment('DOD_TEST_MODE');

  void _up() {
    if (_c.status == AnimationStatus.completed) return;
    if (_clickConfirms && !widget.done) {
      _c.value = 1; // completes, which fires _onStatus once
      return;
    }
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Semantics(
      container: true,
      button: true,
      label: widget.done ? widget.doneLabel : widget.label,
      onLongPress: widget.done ? null : widget.onConfirmed,
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: p.sys.withValues(alpha: .06),
            border: Border.all(
              color: (widget.done ? Hud.gold : p.sys).withValues(
                alpha: p.lineAlpha + .05,
              ),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.done ? 1 : _c.value,
                  child: ColoredBox(
                    color: (widget.done ? Hud.gold : p.sys).withValues(
                      alpha: .22,
                    ),
                  ),
                ),
              ),
              Center(
                child: ExcludeSemantics(
                  child: Text(
                    widget.done ? widget.doneLabel : widget.label,
                    style: Hud.mono(
                      11,
                      widget.done ? Hud.gold : p.hi,
                      spacing: .1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null
        ? null
        : (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? .97 : 1,
      duration: const Duration(milliseconds: 80),
      child: widget.child,
    ),
  );
}

/// Ticks every second while mounted; used for countdowns.
class Ticker1s extends StatefulWidget {
  const Ticker1s({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<Ticker1s> createState() => _Ticker1sState();
}

class _Ticker1sState extends State<Ticker1s> {
  // Started in initState: a lazy `late final` field would never be created,
  // because nothing reads it until dispose.
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

String hms(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(s ~/ 3600)}:${two(s % 3600 ~/ 60)}:${two(s % 60)}';
}
