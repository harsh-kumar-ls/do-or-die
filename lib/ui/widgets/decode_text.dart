import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Text that resolves from random glyphs, left to right.
class DecodeText extends StatefulWidget {
  const DecodeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration delay;
  final Duration duration;

  @override
  State<DecodeText> createState() => _DecodeTextState();
}

class _DecodeTextState extends State<DecodeText> {
  static const _glyphs = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%&*+=<>';
  static const _keep = ' []:.·/';
  static const _frame = Duration(milliseconds: 28);

  final _random = Random();
  Timer? _timer;
  late String _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(DecodeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _start();
  }

  void _start() {
    if (!mounted) return;
    _timer?.cancel();
    if (MediaQuery.of(context).disableAnimations) {
      setState(() => _shown = widget.text);
      return;
    }
    final total = max(
      1,
      widget.duration.inMilliseconds ~/ _frame.inMilliseconds,
    );
    var frame = 0;
    setState(() => _shown = _scramble(0));
    _timer = Timer(widget.delay, () {
      _timer = Timer.periodic(_frame, (t) {
        frame++;
        if (!mounted) return t.cancel();
        if (frame >= total) {
          t.cancel();
          setState(() => _shown = widget.text);
        } else {
          setState(() => _shown = _scramble(frame / total));
        }
      });
    });
  }

  String _scramble(double progress) {
    final text = widget.text;
    final solved = (progress * text.length).floor();
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      out.write(
        i < solved || _keep.contains(ch)
            ? ch
            : _glyphs[_random.nextInt(_glyphs.length)],
      );
    }
    return out.toString();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    _shown,
    style: widget.style,
    textAlign: widget.textAlign,
    semanticsLabel: widget.text,
  );
}
