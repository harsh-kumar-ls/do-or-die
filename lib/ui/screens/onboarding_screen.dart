import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/codec.dart';
import '../../domain/penalty.dart';
import '../../domain/penalty_kind.dart';
import '../../domain/placement.dart';
import '../../domain/progression.dart';
import '../../domain/system_catalogue.dart';
import '../../domain/systems.dart';
import '../../domain/tasks.dart';
import '../../platform/blocker.dart';
import '../fx.dart';
import '../theme.dart';
import '../widgets/awakening_art.dart';
import '../widgets/system_frame.dart';

class OnboardingResult {
  const OnboardingResult({
    required this.system,
    required this.placement,
    required this.answers,
    required this.sleep,
    required this.blocked,
  });

  final SystemKind system;
  final Rank placement;
  final Map<String, int> answers;
  final SleepWindow sleep;
  final Set<String> blocked;
}

/// The Awakening, built from the Claude Design prototype
/// (design/claude-design/awakening.html): system contact, choose a System,
/// placement test, rank stamp and daily quest, lock targets, rest ring,
/// penalty terms. The look and motion follow the design; the quests,
/// placement questions and penalties are the real rules.
///
/// With [nextSystemOnly], only the System choice, placement and quest are
/// shown (choosing the next System once the current one is complete).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.blocker,
    required this.onDone,
    this.nextSystemOnly = false,
    this.completed = const {},
    this.yesterdaySocialMinutes,
  });

  final AppBlocker blocker;
  final ValueChanged<OnboardingResult> onDone;
  final bool nextSystemOnly;

  /// Systems already complete; they can't be chosen again.
  final Set<SystemKind> completed;

  /// Measured from usage access when available, to prefill the Focus test.
  final int? yesterdaySocialMinutes;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { contact, system, placement, quest, apps, rest, terms }

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final List<_Step> _steps = widget.nextSystemOnly
      ? const [_Step.system, _Step.placement, _Step.quest]
      : _Step.values;
  int _index = 0;
  _Step get _step => _steps[_index];

  final _fx = FlashController();
  SystemKind? _system;
  final _answers = <String, int>{};
  int _sleepStart = 23 * 60;
  int _sleepEnd = 7 * 60;
  final _blocked = <String>{};
  bool _registered = false;

  /// Before first contact the whole screen is black.
  bool _contacted = false;

  Rank get _placement => placementFor(_system!, _answers);

  void _go(int index) => setState(() => _index = index);

  void _next() {
    if (_index == _steps.length - 1) return _finish();
    _go(_index + 1);
  }

  void _back() {
    if (_index > 0) _go(_index - 1);
  }

  void _choose(SystemKind k) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_system != k) _answers.clear();
      _system = k;
      for (final q in placementQuestions[k]!) {
        _answers.putIfAbsent(
          q.id,
          () => q.id == 'social_minutes'
              ? widget.yesterdaySocialMinutes ?? q.initial
              : q.initial,
        );
      }
    });
  }

  void _finish() {
    widget.onDone(
      OnboardingResult(
        system: _system!,
        placement: _placement,
        answers: {..._answers},
        sleep: SleepWindow(startMinute: _sleepStart, endMinute: _sleepEnd),
        blocked: {..._blocked},
      ),
    );
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_step) {
      _Step.contact => _ContactStep(
        fx: _fx,
        onContact: () => setState(() => _contacted = true),
        onAccepted: () {
          _fx.flash();
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) _next();
          });
        },
      ),
      _Step.system => _SystemStep(
        choices: [
          for (final k in SystemKind.values)
            if (!widget.completed.contains(k)) k,
        ],
        chosen: _system,
        nextSystemOnly: widget.nextSystemOnly,
        onChoose: _choose,
        onBind: () {
          _fx.flash();
          Fx.instance.play(Cue.window);
          _next();
        },
      ),
      _Step.placement => _PlacementStep(
        kind: _system!,
        answers: _answers,
        onChanged: (id, v) => setState(() => _answers[id] = v),
        onSubmit: _next,
      ),
      _Step.quest => _QuestStep(
        key: ValueKey('$_system$_placement'),
        kind: _system!,
        rank: _placement,
        fx: _fx,
        label: widget.nextSystemOnly ? 'BEGIN THIS SYSTEM' : 'CONTINUE',
        onContinue: _next,
      ),
      _Step.apps => _AppsStep(
        blocker: widget.blocker,
        selected: _blocked,
        onToggle: (pkg) => setState(
          () =>
              _blocked.contains(pkg) ? _blocked.remove(pkg) : _blocked.add(pkg),
        ),
        onConfirm: _next,
      ),
      _Step.rest => _RestStep(
        start: _sleepStart,
        end: _sleepEnd,
        onChanged: (s, e) => setState(() {
          _sleepStart = s;
          _sleepEnd = e;
        }),
        onConfirm: _next,
      ),
      _Step.terms => _TermsStep(
        kind: _system!,
        lockTargets: _blocked.length,
        sleepStart: _sleepStart,
        sleepEnd: _sleepEnd,
        onAccepted: () {
          _fx
            ..flash()
            ..shake();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _registered = true);
          });
        },
      ),
    };
    final contact = _step == _Step.contact;
    return FlashLayer(
      controller: _fx,
      child: Stack(
        children: [
          if (contact && !_contacted)
            const Positioned.fill(child: ColoredBox(color: Colors.black)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedOpacity(
                    opacity: contact ? 0 : 1,
                    duration: const Duration(milliseconds: 400),
                    child: _Progress(index: _index, count: _steps.length),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      reverseDuration: const Duration(milliseconds: 120),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, .012),
                            end: Offset.zero,
                          ).animate(a),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(key: ValueKey(_step), child: body),
                    ),
                  ),
                  if (_index > 0 && !_registered)
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: TextButton(
                          onPressed: _back,
                          child: Text(
                            'BACK',
                            style: Hud.mono(11, HudScope.of(context).dim),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_registered)
            Positioned.fill(
              child: _Registered(
                kind: _system!,
                rank: _placement,
                lockTargets: _blocked.length,
                sleepStart: _sleepStart,
                sleepEnd: _sleepEnd,
                onEnter: _finish,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces

class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.count});
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 2,
              color: p.sys.withValues(alpha: .18),
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                widthFactor: i < index ? 1 : (i == index ? .5 : 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.sys,
                    boxShadow: [BoxShadow(color: p.glowColor, blurRadius: 8)],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Text(
          '${(index + 1).toString().padLeft(2, '0')}/${count.toString().padLeft(2, '0')}',
          style: Hud.mono(10, p.dim, spacing: .14),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.kicker, required this.title, this.sub});
  final String kicker;
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker.toUpperCase(), style: Hud.mono(10, p.dim, spacing: .24)),
          const SizedBox(height: 6),
          Text(
            title.toUpperCase(),
            style: Hud.head(
              20,
              p.hi,
              spacing: .22,
            ).copyWith(shadows: p.textGlow(1)),
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub!, style: Hud.mono(12, p.dim).copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

String _hm(int m) =>
    '${(m ~/ 60 % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Step 1: system contact

class _ContactStep extends StatefulWidget {
  const _ContactStep({
    required this.fx,
    required this.onAccepted,
    required this.onContact,
  });
  final FlashController fx;
  final VoidCallback onContact;
  final VoidCallback onAccepted;

  @override
  State<_ContactStep> createState() => _ContactStepState();
}

class _ContactStepState extends State<_ContactStep>
    with TickerProviderStateMixin {
  static const _message = 'You have met the conditions to become a Player.';

  late final _converge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final _window = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  final _particles = ParticlePainter.make(Random());
  bool _contacted = false;
  bool _emblem = false;
  int _typed = 0;
  Timer? _typer;

  @override
  void dispose() {
    _typer?.cancel();
    _converge.dispose();
    _window.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _contact() async {
    if (_contacted) return;
    setState(() => _contacted = true);
    widget.onContact();
    HapticFeedback.mediumImpact();
    await _converge.forward();
    if (!mounted) return;
    setState(() => _emblem = true);
    unawaited(_pulse.repeat(reverse: true));
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    widget.fx.flash();
    Fx.instance.play(Cue.notice);
    await _window.forward();
    if (!mounted) return;
    _typer = Timer.periodic(const Duration(milliseconds: 28), (t) {
      if (!mounted) return t.cancel();
      setState(() => _typed++);
      if (_typed >= _message.length) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    if (!_contacted) {
      return Semantics(
        button: true,
        label: 'Touch to establish contact',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _contact,
          child: ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Blink(child: Text('_', style: Hud.mono(22, p.sys))),
                  const SizedBox(height: 16),
                  ExcludeSemantics(
                    child: Text(
                      'TOUCH TO ESTABLISH CONTACT',
                      style: Hud.mono(10, p.dim, spacing: .24),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final done = _typed >= _message.length;
    return LayoutBuilder(
      builder: (context, c) {
        final centre = Offset(
          c.maxWidth / 2,
          min(150.0, c.maxHeight * .2) + 80,
        );
        return Stack(
          children: [
            if (!_emblem)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _converge,
                  builder: (context, _) => CustomPaint(
                    painter: ParticlePainter(
                      _converge.value,
                      centre,
                      _particles,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: centre.dx - 80,
              top: centre.dy - 80,
              child: AnimatedOpacity(
                opacity: _emblem ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    size: const Size(160, 160),
                    painter: EmblemPainter(glow: 1 + _pulse.value),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: centre.dy + 110,
              child: AnimatedBuilder(
                animation: _window,
                builder: (context, child) => Opacity(
                  opacity: _window.value == 0 ? 0 : 1,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      1,
                      .02 + .98 * Curves.easeOutExpo.transform(_window.value),
                      1,
                    ),
                    child: child,
                  ),
                ),
                child: HudFrame(
                  title: '[ NOTIFICATION ]',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Text(
                          _message.substring(0, min(_typed, _message.length)) +
                              (done ? '' : '_'),
                          style: Hud.mono(16, p.text).copyWith(height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Acceptance binds you to the System.',
                        style: Hud.mono(12, p.dim),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: AnimatedOpacity(
                opacity: done ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !done,
                  child: Column(
                    children: [
                      ChargeButton(
                        label: 'ACCEPT',
                        enabled: done,
                        onConfirmed: () {
                          Fx.instance.play(Cue.confirm);
                          widget.onAccepted();
                        },
                      ),
                      const SizedBox(height: 10),
                      Text('Hold to accept', style: Hud.mono(12, p.dim)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Blink extends StatefulWidget {
  const _Blink({required this.child});
  final Widget child;

  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) =>
        Opacity(opacity: _c.value < .5 ? 1 : 0, child: child),
    child: widget.child,
  );
}

// ---------------------------------------------------------------------------
// Step 2: choose your System

/// Choose your System: a carousel of flip cards (neighbours scaled to 0.92
/// and dimmed), each with its animated emblem on the front and a brief on
/// the back. The centred card is the choice.
class _SystemStep extends StatefulWidget {
  const _SystemStep({
    required this.choices,
    required this.chosen,
    required this.nextSystemOnly,
    required this.onChoose,
    required this.onBind,
  });

  final List<SystemKind> choices;
  final SystemKind? chosen;
  final bool nextSystemOnly;
  final ValueChanged<SystemKind> onChoose;
  final VoidCallback onBind;

  @override
  State<_SystemStep> createState() => _SystemStepState();
}

class _SystemStepState extends State<_SystemStep>
    with SingleTickerProviderStateMixin {
  late final _page = PageController(
    viewportFraction: .8,
    initialPage: max(
      0,
      widget.choices.indexOf(widget.chosen ?? widget.choices.first),
    ),
  );
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(days: 1),
  )..forward();
  final _flipped = <SystemKind>{};

  int get _index => _page.hasClients
      ? (_page.page ?? _page.initialPage.toDouble()).round()
      : _page.initialPage;

  @override
  void initState() {
    super.initState();
    // The centred card is chosen from the start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.chosen == null) {
        widget.onChoose(widget.choices[_page.initialPage]);
      }
    });
  }

  @override
  void dispose() {
    _page.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _goTo(int i) => _page.animateToPage(
    i,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final chosen = widget.chosen ?? widget.choices.first;
    final name = systemCatalogue[chosen]!.name.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(
          kicker: 'Awakening · System binding',
          title: 'Choose your System',
          sub: widget.nextSystemOnly
              ? 'Your System is complete. Choose the next one.'
              : null,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => OverflowBox(
              // The carousel runs edge to edge, past the step's 20 px padding.
              minWidth: box.maxWidth + 40,
              maxWidth: box.maxWidth + 40,
              child: AnimatedBuilder(
                animation: Listenable.merge([_page, _clock]),
                builder: (context, _) => PageView.builder(
                  controller: _page,
                  itemCount: widget.choices.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    widget.onChoose(widget.choices[i]);
                  },
                  itemBuilder: (context, i) {
                    final page =
                        _page.hasClients && _page.position.haveDimensions
                        ? (_page.page ?? 0)
                        : _page.initialPage.toDouble();
                    final d = (page - i).abs().clamp(0.0, 1.0);
                    final k = widget.choices[i];
                    return Transform.scale(
                      scale: 1 - .08 * d,
                      child: Opacity(
                        opacity: 1 - .45 * d,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 8,
                          ),
                          child: _FlipCard(
                            kind: k,
                            index: i,
                            count: widget.choices.length,
                            active: d < .5,
                            flipped: _flipped.contains(k),
                            seconds: _clock.lastElapsedDuration == null
                                ? 0
                                : _clock.lastElapsedDuration!.inMilliseconds /
                                      1000,
                            onTap: () {
                              if (i != _index) return _goTo(i);
                              HapticFeedback.selectionClick();
                              setState(
                                () => _flipped.contains(k)
                                    ? _flipped.remove(k)
                                    : _flipped.add(k),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, k) in widget.choices.indexed)
              Semantics(
                button: true,
                selected: k == chosen,
                label: 'Show the ${systemCatalogue[k]!.name}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _goTo(i),
                  child: SizedBox(
                    width: 48,
                    height: 36,
                    child: Center(
                      child: Transform.rotate(
                        angle: pi / 4,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: k == chosen ? 11 : 8,
                          height: k == chosen ? 11 : 8,
                          decoration: BoxDecoration(
                            color: k == chosen ? p.sys : Colors.transparent,
                            border: Border.all(
                              color: k == chosen ? p.hi : p.dim,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Text.rich(
          TextSpan(
            text: 'One System at a time. ',
            style: Hud.mono(11, p.dim),
            children: [
              TextSpan(
                text: 'No switching until it is complete.',
                style: Hud.mono(11, Hud.warn),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        CutButton('CHOOSE $name', onPressed: widget.onBind),
      ],
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.kind,
    required this.index,
    required this.count,
    required this.active,
    required this.flipped,
    required this.seconds,
    required this.onTap,
  });

  final SystemKind kind;
  final int index;
  final int count;
  final bool active;
  final bool flipped;
  final double seconds;
  final VoidCallback onTap;

  static const _statFull = {
    Stat.strength: 'STRENGTH',
    Stat.intellect: 'INTELLECT',
    Stat.discipline: 'DISCIPLINE',
    Stat.vitality: 'VITALITY',
    Stat.charisma: 'CHARISMA',
  };
  static const _stat = {
    Stat.strength: 'STR',
    Stat.intellect: 'INT',
    Stat.discipline: 'DIS',
    Stat.vitality: 'VIT',
    Stat.charisma: 'CHA',
  };
  static const _end = {
    SystemKind.fitness: 'A full-intensity personal programme, logged daily.',
    SystemKind.personality:
        'Create something every day: write, build or present.',
    SystemKind.focus: 'Locked apps stay locked all day, by choice.',
  };

  @override
  Widget build(BuildContext context) {
    final spec = systemCatalogue[kind]!;
    return Semantics(
      button: true,
      label: spec.name,
      hint: flipped ? 'Tap to return' : 'Tap to inspect',
      child: GestureDetector(
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: flipped ? 1 : 0),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          builder: (context, f, _) {
            final back = f > .5;
            final angle = f * pi;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .0012)
                ..rotateY(angle),
              child: back
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: _face(context, spec, back: true),
                    )
                  : _face(context, spec, back: false),
            );
          },
        ),
      ),
    );
  }

  Widget _face(BuildContext context, SystemSpec spec, {required bool back}) {
    final p = HudScope.of(context);
    final short = spec.name.split(' ').first.toUpperCase();
    final content = back
        ? _back(context, spec, short)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'SYSTEM 0${index + 1} / 0$count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Hud.mono(10, p.dim, spacing: .2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'START · RANK E',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Hud.mono(10, Hud.rankColor(Rank.e), spacing: .2),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: SystemEmblemPainter(kind, active ? seconds : 0),
                    ),
                  ),
                ),
              ),
              Text(
                short,
                textAlign: TextAlign.center,
                style: Hud.head(
                  26,
                  p.hi,
                  spacing: .26,
                ).copyWith(shadows: p.textGlow(1)),
              ),
              const SizedBox(height: 8),
              Text(
                spec.tagline,
                textAlign: TextAlign.center,
                style: Hud.mono(13, p.text).copyWith(height: 1.55),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final s in spec.stats)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 96),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: p.sys.withValues(alpha: .06),
                        border: Border.all(color: p.sys.withValues(alpha: .55)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _stat[s]!,
                            style: Hud.head(15, p.hi, spacing: .22),
                          ),
                          Text(
                            _statFull[s]!,
                            style: Hud.mono(9, p.dim, spacing: .16),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flip, size: 16, color: active ? p.sys : p.dim),
                  const SizedBox(width: 8),
                  Text(
                    'TAP TO INSPECT',
                    style: Hud.mono(10, active ? p.sys : p.dim, spacing: .22),
                  ),
                ],
              ),
            ],
          );
    return HudFrame(
      chamfer: 16,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      expand: true,
      child: content,
    );
  }

  Widget _back(BuildContext context, SystemSpec spec, String short) {
    final p = HudScope.of(context);
    Widget sh(String a, String b, Color c) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Flexible(
            child: Text(
              a,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Hud.mono(9, p.dim, spacing: .2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              b,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Hud.mono(9, c, spacing: .2),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '[ $short · BRIEF ]',
          textAlign: TextAlign.center,
          style: Hud.head(
            12,
            p.hi,
            spacing: .24,
          ).copyWith(shadows: p.textGlow(.8)),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 10, bottom: 12),
          color: p.sys.withValues(alpha: .18),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sh('WHERE YOU START', 'RANK E · TODAY', Hud.rankColor(Rank.e)),
                for (final t in spec.at(Rank.e).daily.map(questTask))
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: p.sys.withValues(alpha: .05),
                      border: Border.all(color: p.sys.withValues(alpha: .18)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(t.name, style: Hud.mono(12, p.text)),
                        ),
                        Text(
                          questTarget(t),
                          style: Hud.mono(
                            12,
                            Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                sh('WHERE IT ENDS', 'RANK S', Hud.rankColor(Rank.s)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Hud.gold.withValues(alpha: .05),
                    border: Border.all(color: Hud.gold.withValues(alpha: .35)),
                  ),
                  child: Text(
                    _end[kind]!,
                    style: Hud.mono(12, Hud.gold).copyWith(height: 1.5),
                  ),
                ),
                const SizedBox(height: 10),
                sh('IF YOU FAIL A DAY', '', p.dim),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock, size: 16, color: Hud.warn),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your chosen apps lock for 4 hours at a time you are not told.',
                        style: Hud.mono(
                          12,
                          const Color(0xFFFFC4CA),
                        ).copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, size: 16, color: Hud.warn),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${penaltyShort(penaltyKindFor(kind))[0].toUpperCase()}${penaltyShort(penaltyKindFor(kind)).substring(1)}, growing with your level.',
                        style: Hud.mono(12, p.text).copyWith(height: 1.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final r in Rank.values)
              Transform.rotate(
                angle: pi / 4,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r == Rank.e
                        ? Hud.rankColor(r)
                        : const Color(0xFF070D1A),
                    border: Border.all(color: Hud.rankColor(r), width: 1.5),
                    boxShadow: r == Rank.e || r == Rank.s
                        ? [
                            BoxShadow(
                              color: Hud.rankColor(r).withValues(alpha: .6),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Transform.rotate(
                    angle: -pi / 4,
                    child: Text(
                      r.name.toUpperCase(),
                      style: Hud.head(
                        11,
                        r == Rank.e
                            ? const Color(0xFF05070D)
                            : Hud.rankColor(r),
                        spacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flip, size: 16, color: p.sys),
            const SizedBox(width: 8),
            Text('TAP TO RETURN', style: Hud.mono(10, p.sys, spacing: .22)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: placement test

class _PlacementStep extends StatelessWidget {
  const _PlacementStep({
    required this.kind,
    required this.answers,
    required this.onChanged,
    required this.onSubmit,
  });

  final SystemKind kind;
  final Map<String, int> answers;
  final void Function(String id, int value) onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final qs = placementQuestions[kind]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(
          kicker: systemCatalogue[kind]!.name,
          title: 'Placement test',
          sub: 'These answers only set your starting rank. Your daily quest is shown next.',
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (i, q) in qs.indexed) ...[
                    if (i > 0) const SizedBox(height: 16),
                    HudFrame(
                      child: _Stepper(
                        key: ValueKey(q.id),
                        index: i,
                        count: qs.length,
                        question: q,
                        value: answers[q.id] ?? q.initial,
                        onChanged: (v) => onChanged(q.id, v),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        CutButton('SUBMIT', onPressed: onSubmit),
      ],
    );
  }
}

/// Big minus / number / plus with press-and-hold repeat, plus a slider. The
/// number can also be typed.
class _Stepper extends StatefulWidget {
  const _Stepper({
    super.key,
    required this.index,
    required this.count,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final int index;
  final int count;
  final PlacementQuestion question;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  late final _c = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();
  Timer? _delay, _repeat;

  @override
  void didUpdateWidget(_Stepper old) {
    super.didUpdateWidget(old);
    if ('${widget.value}' != _c.text && !_focus.hasFocus) {
      _c.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _stopRepeat();
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  void _set(int v) {
    final q = widget.question;
    final clamped = v.clamp(q.min, q.max);
    _c.text = '$clamped';
    widget.onChanged(clamped);
  }

  void _bump(int dir) {
    HapticFeedback.selectionClick();
    final cur = int.tryParse(_c.text) ?? widget.value;
    _set(cur + dir * widget.question.step);
  }

  void _startRepeat(int dir) {
    _stopRepeat();
    _bump(dir);
    _delay = Timer(const Duration(milliseconds: 380), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 70),
        (_) => _bump(dir),
      );
    });
  }

  void _stopRepeat() {
    _delay?.cancel();
    _repeat?.cancel();
  }

  Widget _pm(String label, int dir, String semantic) {
    final p = HudScope.of(context);
    return Semantics(
      button: true,
      label: semantic,
      onTap: () => _bump(dir),
      child: Listener(
        onPointerDown: (_) => _startRepeat(dir),
        onPointerUp: (_) => _stopRepeat(),
        onPointerCancel: (_) => _stopRepeat(),
        child: ClipPath(
          clipper: const ChamferClipper(8, corners: [true, false, true, false]),
          child: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.sys.withValues(alpha: .06),
              border: Border.all(color: p.sys),
            ),
            child: ExcludeSemantics(
              child: Text(label, style: Hud.head(28, p.hi, spacing: 0)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final q = widget.question;
    final v = widget.value.clamp(q.min, q.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUESTION ${widget.index + 1} / ${widget.count}',
          style: Hud.mono(10, p.sys, spacing: .2),
        ),
        const SizedBox(height: 6),
        Text(q.prompt, style: Hud.mono(13, p.text).copyWith(height: 1.5)),
        const SizedBox(height: 14),
        Row(
          children: [
            _pm('−', -1, 'Decrease'),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Semantics(
                    label: q.prompt,
                    child: TextField(
                      controller: _c,
                      focusNode: _focus,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: Hud.head(
                        40,
                        Colors.white,
                        spacing: 0,
                      ).copyWith(shadows: p.textGlow(1)),
                      cursorColor: p.sys,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (s) {
                        final n = int.tryParse(s);
                        if (n != null) widget.onChanged(n.clamp(q.min, q.max));
                      },
                    ),
                  ),
                  Text(
                    q.unit.toUpperCase(),
                    style: Hud.mono(10, p.dim, spacing: .2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _pm('+', 1, 'Increase'),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: p.sys,
            inactiveTrackColor: p.sys.withValues(alpha: .18),
            thumbColor: p.voidColor,
            overlayColor: p.sys.withValues(alpha: .12),
            thumbShape: _DiamondThumb(p.hi),
          ),
          child: ExcludeSemantics(
            child: Slider(
              min: q.min.toDouble(),
              max: q.max.toDouble(),
              value: v.toDouble(),
              onChanged: (x) {
                final snapped = (x / q.step).round() * q.step;
                if (snapped != widget.value) _set(snapped);
              },
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${q.min}', style: Hud.mono(10, p.dim)),
            Text('${q.max}+', style: Hud.mono(10, p.dim)),
          ],
        ),
      ],
    );
  }
}

class _DiamondThumb extends SliderComponentShape {
  const _DiamondThumb(this.color);
  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(22, 22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final path = Path()
      ..moveTo(center.dx, center.dy - 10)
      ..lineTo(center.dx + 10, center.dy)
      ..lineTo(center.dx, center.dy + 10)
      ..lineTo(center.dx - 10, center.dy)
      ..close();
    context.canvas
      ..drawPath(path, Paint()..color = const Color(0xFF05070D))
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }
}

// ---------------------------------------------------------------------------
// Step 4: rank stamp and daily quest

class _QuestStep extends StatefulWidget {
  const _QuestStep({
    super.key,
    required this.kind,
    required this.rank,
    required this.fx,
    required this.label,
    required this.onContinue,
  });

  final SystemKind kind;
  final Rank rank;
  final FlashController fx;
  final String label;
  final VoidCallback onContinue;

  @override
  State<_QuestStep> createState() => _QuestStepState();
}

class _QuestStepState extends State<_QuestStep> with TickerProviderStateMixin {
  late final _stamp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  int _dealt = 0;
  bool _ready = false;
  final _timers = <Timer>[];

  late final _spec = systemCatalogue[widget.kind]!;
  late final _quest = _spec.at(widget.rank).daily.map(questTask).toList();

  @override
  void initState() {
    super.initState();
    _timers.add(
      Timer(const Duration(milliseconds: 250), () async {
        await _stamp.forward();
        if (!mounted) return;
        widget.fx
          ..flash()
          ..shake();
        HapticFeedback.heavyImpact();
        Fx.instance.play(Cue.levelUp);
        unawaited(_ring.forward());
        setState(() {});
      }),
    );
    for (var i = 0; i < _quest.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: 1000 + i * 140), () {
          if (mounted) setState(() => _dealt = i + 1);
        }),
      );
    }
    _timers.add(
      Timer(Duration(milliseconds: 1000 + _quest.length * 140 + 400), () {
        if (mounted) setState(() => _ready = true);
      }),
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _stamp.dispose();
    _ring.dispose();
    super.dispose();
  }

  String get _tease {
    final r = widget.rank;
    if (r == Rank.s) {
      return 'Rank S. Hold it for 30 days to complete the System.';
    }
    final next = Rank.values[r.index + 1];
    final have = {for (final q in _spec.at(r).daily) q.id};
    final added = [
      for (final q in _spec.at(next).daily)
        if (!have.contains(q.id)) q.label,
    ];
    final n = next.name.toUpperCase();
    return added.isEmpty
        ? 'At rank $n the System raises every target.'
        : 'At rank $n the System adds: ${added.join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final rc = Hud.rankColor(widget.rank);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 124),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_stamp, _ring]),
                builder: (context, _) {
                  final t = Curves.easeInQuad.transform(_stamp.value);
                  return Opacity(
                    opacity: _stamp.value,
                    child: Transform.scale(
                      scale: 2.4 - 1.4 * t,
                      child: CustomPaint(
                        size: const Size(116, 124),
                        painter: RankHexPainter(widget.rank, ring: _ring.value),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnimatedOpacity(
                  opacity: _stamp.isCompleted ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RANK ASSIGNED',
                        style: Hud.mono(10, p.dim, spacing: .24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RANK ${widget.rank.name.toUpperCase()}',
                        style: Hud.head(22, rc, spacing: .2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _spec.name.toUpperCase(),
                        style: Hud.mono(11, p.text, spacing: .12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ranks above C are earned only through Dungeons.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Hud.mono(10, p.dim).copyWith(height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: HudFrame(
            title: '[ DAILY QUEST ]',
            expand: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'CLEAR BEFORE 23:59',
                        overflow: TextOverflow.ellipsis,
                        style: Hud.mono(10, p.dim, spacing: .16),
                      ),
                    ),
                    Text(
                      '+100 XP',
                      style: Hud.mono(10, Hud.gold, spacing: .16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final (i, t) in _quest.indexed)
                          _DealtCard(shown: i < _dealt, index: i + 1, task: t),
                      ],
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _ready ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Hud.gold.withValues(alpha: .4)),
                    ),
                    child: Text(
                      _tease,
                      style: Hud.mono(12, Hud.gold).copyWith(height: 1.5),
                    ),
                  ),
                ),
                if (widget.kind == SystemKind.fitness) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Conservative progressions, not medical advice. With a health condition, ask a doctor first.',
                    style: Hud.mono(10, Hud.warn).copyWith(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        CutButton(widget.label, onPressed: _ready ? widget.onContinue : null),
      ],
    );
  }
}

class _DealtCard extends StatelessWidget {
  const _DealtCard({
    required this.shown,
    required this.index,
    required this.task,
  });
  final bool shown;
  final int index;
  final TaskDefinition task;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return AnimatedSlide(
      offset: shown ? Offset.zero : const Offset(.12, 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: p.sys.withValues(alpha: .04),
            border: Border.all(color: p.sys.withValues(alpha: .18)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: Hud.mono(11, p.sys, weight: FontWeight.w700),
                ),
              ),
              Expanded(child: Text(task.name, style: Hud.mono(13, p.text))),
              const SizedBox(width: 8),
              Text(
                questTarget(task),
                style: Hud.mono(15, Colors.white, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5: lock targets

class _AppsStep extends StatefulWidget {
  const _AppsStep({
    required this.blocker,
    required this.selected,
    required this.onToggle,
    required this.onConfirm,
  });

  final AppBlocker blocker;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onConfirm;

  @override
  State<_AppsStep> createState() => _AppsStepState();
}

class _AppsStepState extends State<_AppsStep> with WidgetsBindingObserver {
  late final Future<List<InstalledApp>> _apps = widget.blocker.installedApps();
  SystemStatus? _status;
  bool _asked = false;

  bool get _granted =>
      !widget.blocker.canBlock ||
      (_status?.usageAccess == true && _status?.overlay == true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android settings: read the permissions again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!widget.blocker.canBlock) return;
    try {
      final s = await widget.blocker.systemStatus();
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  Future<void> _grant() async {
    setState(() => _asked = true);
    if (_status?.usageAccess != true) {
      await widget.blocker.requestUsageAccess();
    } else if (_status?.overlay != true) {
      await widget.blocker.requestOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final android = widget.blocker.canBlock;
    final granted = _granted;
    final missing = _status?.usageAccess != true
        ? 'usage access'
        : 'display over other apps';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Head(
          kicker: 'Penalty configuration',
          title: 'Lock targets',
          sub: 'Selected apps lock on a failed day. Screen-time quests measure them.',
        ),
        if (android) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (granted ? p.sys : Hud.warn).withValues(alpha: .06),
              border: Border.all(
                color: granted
                    ? p.sys.withValues(alpha: .18)
                    : Hud.warn.withValues(alpha: .5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        granted ? 'ACCESS GRANTED' : 'ACCESS REQUIRED',
                        style: Hud.head(
                          11,
                          granted ? Hud.rankColor(Rank.d) : Hud.warn,
                          spacing: .2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        granted
                            ? 'The System can lock selected apps.'
                            : 'The System needs $missing to lock apps.'
                                  '${_asked ? ' If Android says "Access denied": App info, top-right menu, "Allow restricted settings", then grant again.' : ''}',
                        style: Hud.mono(11, p.text).copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
                if (!granted) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    child: CutButton('GRANT', onPressed: _grant, danger: true),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('INSTALLED APPS', style: Hud.mono(11, p.dim)),
            Text.rich(
              TextSpan(
                text: 'LOCKED ',
                style: Hud.mono(11, p.dim),
                children: [
                  TextSpan(
                    text: '${widget.selected.length}',
                    style: Hud.mono(11, Hud.warn, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AnimatedOpacity(
            opacity: granted ? 1 : .35,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !granted,
              child: FutureBuilder<List<InstalledApp>>(
                future: _apps,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return Center(
                      child: Text(
                        'Scanning apps...',
                        style: Hud.mono(11, p.dim),
                      ),
                    );
                  }
                  final apps = snap.data ?? const <InstalledApp>[];
                  if (apps.isEmpty) {
                    return Center(
                      child: Text(
                        'No apps to list on this device.',
                        style: Hud.mono(11, p.dim),
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .78,
                        ),
                    itemCount: apps.length,
                    itemBuilder: (context, i) => _AppTile(
                      app: apps[i],
                      locked: widget.selected.contains(apps[i].package),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onToggle(apps[i].package);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('NEVER LOCKED', style: Hud.mono(10, p.dim, spacing: .24)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final s in const [
              'PHONE',
              'MESSAGES',
              'MAPS',
              'SETTINGS',
              'DO OR DIE',
            ])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: p.sys.withValues(alpha: .18)),
                ),
                child: Text(s, style: Hud.mono(10, Hud.rankColor(Rank.d))),
              ),
          ],
        ),
        const SizedBox(height: 14),
        CutButton(
          'CONFIRM TARGETS',
          onPressed: granted && (!android || widget.selected.isNotEmpty)
              ? widget.onConfirm
              : null,
        ),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.locked,
    required this.onTap,
  });
  final InstalledApp app;
  final bool locked;
  final VoidCallback onTap;

  static const _grey = ColorFilter.matrix([
    .2, .4, .1, 0, 0, //
    .2, .4, .1, 0, 0, //
    .2, .4, .1, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final icon = SizedBox(
      width: 46,
      height: 46,
      child: app.icon == null
          ? Icon(Icons.apps, color: p.dim)
          : Image.memory(app.icon!, gaplessPlayback: true),
    );
    return Semantics(
      button: true,
      selected: locked,
      label: '${locked ? 'Unlock' : 'Lock'} ${app.label}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: locked
                ? Hud.warn.withValues(alpha: .07)
                : Colors.transparent,
            border: Border.all(
              color: locked
                  ? Hud.warn.withValues(alpha: .55)
                  : Colors.transparent,
            ),
          ),
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      locked
                          ? ColorFiltered(colorFilter: _grey, child: icon)
                          : icon,
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Hud.mono(10, locked ? Hud.warn : p.dim),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: AnimatedScale(
                    scale: locked ? 1 : .4,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedOpacity(
                      opacity: locked ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.lock, size: 16, color: Hud.warn),
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

// ---------------------------------------------------------------------------
// Step 6: rest period ring

class _RestStep extends StatelessWidget {
  const _RestStep({
    required this.start,
    required this.end,
    required this.onChanged,
    required this.onConfirm,
  });

  final int start;
  final int end;
  final void Function(int start, int end) onChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final d = RestRing.restMinutes(start, end);
    final problem = RestRing.problem(start, end);
    Widget legend(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: c),
        const SizedBox(width: 6),
        Text(t, style: Hud.mono(10, p.dim, spacing: .12)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Head(
          kicker: 'Penalty configuration',
          title: 'Rest period',
          sub: 'Locks never start while you sleep. Drag both markers.',
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: RestRing(start: start, end: end, onChanged: onChanged),
              ),
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_hm(start)} → ${_hm(end)}',
                      style: Hud.mono(
                        22,
                        Colors.white,
                        weight: FontWeight.w700,
                      ).copyWith(shadows: p.textGlow(1)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${d ~/ 60} H ${(d % 60).toString().padLeft(2, '0')} M REST',
                      style: Hud.head(13, p.hi, spacing: .2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      problem ?? '',
                      style: Hud.mono(10, Hud.warn, spacing: .14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            legend(const Color(0xFFA9DCFF), 'SLEEP'),
            const SizedBox(width: 18),
            legend(Hud.gold, 'WAKE'),
            const SizedBox(width: 18),
            legend(p.sys.withValues(alpha: .5), 'NO LOCKS'),
          ],
        ),
        const SizedBox(height: 14),
        CutButton(
          'SET REST PERIOD',
          onPressed: problem == null ? onConfirm : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 7: penalty terms

class _TermsStep extends StatefulWidget {
  const _TermsStep({
    required this.kind,
    required this.lockTargets,
    required this.sleepStart,
    required this.sleepEnd,
    required this.onAccepted,
  });

  final SystemKind kind;
  final int lockTargets;
  final int sleepStart;
  final int sleepEnd;
  final VoidCallback onAccepted;

  @override
  State<_TermsStep> createState() => _TermsStepState();
}

class _TermsStepState extends State<_TermsStep> {
  final _scroll = ScrollController();
  final _listKey = GlobalKey();
  final _seen = <int>{};
  late final List<(String, bool)> _lines = [
    (
      'Clear every objective of the daily quest before 23:59. Partial completion is failure.',
      false,
    ),
    ('Failure opens the Penalty Zone the next day.', true),
    (
      'Your ${widget.lockTargets} lock target${widget.lockTargets == 1 ? '' : 's'} close for 4 hours (+20 minutes per level), at a time the System does not disclose.',
      true,
    ),
    (
      'Locks never begin during your rest period, ${_hm(widget.sleepStart)} to ${_hm(widget.sleepEnd)}.',
      false,
    ),
    (
      'Calls, messages, maps and settings are never locked. A 15-minute release always exists; every one is counted.',
      false,
    ),
    (
      'The System penalty: ${penaltyTerms(penaltyKindFor(widget.kind))}. Anything unpaid doubles at midnight.',
      true,
    ),
    (
      'Clear 21 of 30 days and a Gate opens. It starts a 3-day Dungeon; Floor 2 must be cleared by 18:00; Floor 3 is the Rank Trial.',
      false,
    ),
    (
      'Fail a Dungeon floor and the Dungeon Penalty doubles every penalty. Ranks never go down.',
      true,
    ),
    (
      'A quest can be lowered by up to 20% for injury or illness, from the next day, at half XP.',
      false,
    ),
    (
      'The first 3 days are a dry run: failures are shown, never enforced.',
      false,
    ),
    ('The System does not negotiate.', false),
  ];
  late final _keys = [for (final _ in _lines) GlobalKey()];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A line counts as read once 70% of it has been on screen.
  void _measure() {
    if (!mounted) return;
    final list = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (list == null || !list.hasSize) return;
    final height = list.size.height;
    var changed = false;
    for (var i = 0; i < _keys.length; i++) {
      if (_seen.contains(i)) continue;
      final box = _keys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: list).dy;
      // Read once 70% of it has come into view; a line scrolled past (even
      // quickly) has been on screen too.
      if (top + box.size.height * .7 <= height) {
        _seen.add(i);
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final all = _seen.length >= _lines.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Head(kicker: 'Final step', title: 'Penalty terms'),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
              return false;
            },
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0, .03, .92, 1],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                key: _listKey,
                controller: _scroll,
                padding: const EdgeInsets.only(top: 6, bottom: 60),
                child: Column(
                  children: [
                    for (final (i, (text, red)) in _lines.indexed)
                      AnimatedSlide(
                        key: _keys[i],
                        offset: _seen.contains(i)
                            ? Offset.zero
                            : const Offset(0, .15),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _seen.contains(i) ? 1 : .08,
                          duration: const Duration(milliseconds: 350),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: p.sys.withValues(alpha: .18),
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    (i + 1).toString().padLeft(2, '0'),
                                    style: Hud.mono(
                                      11,
                                      red ? const Color(0xFFFF3B4A) : Hud.warn,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: Hud.mono(
                                      14,
                                      red ? const Color(0xFFFFD6DA) : p.text,
                                    ).copyWith(height: 1.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          all
              ? 'ALL TERMS READ'
              : 'SCROLL TO READ ALL TERMS · ${_seen.length}/${_lines.length}',
          textAlign: TextAlign.center,
          style: Hud.mono(10, p.dim, spacing: .16),
        ),
        const SizedBox(height: 10),
        ChargeButton(
          label: 'HOLD TO ACCEPT',
          danger: true,
          enabled: all,
          onConfirmed: () {
            Fx.instance.play(Cue.penalty);
            widget.onAccepted();
          },
        ),
      ],
    );
  }
}

class _Registered extends StatelessWidget {
  const _Registered({
    required this.kind,
    required this.rank,
    required this.lockTargets,
    required this.sleepStart,
    required this.sleepEnd,
    required this.onEnter,
  });

  final SystemKind kind;
  final Rank rank;
  final int lockTargets;
  final int sleepStart;
  final int sleepEnd;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    Widget row(String k, String v, [Color? c]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: Hud.mono(11, p.dim, spacing: .14)),
          ),
          Expanded(child: Text(v, style: Hud.mono(13, c ?? p.text))),
        ],
      ),
    );
    return ColoredBox(
      color: const Color(0xDB05070D),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: HudFrame(
              title: '[ PLAYER REGISTERED ]',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  row('SYSTEM', systemCatalogue[kind]!.name.toUpperCase()),
                  row('RANK', rank.name.toUpperCase(), Hud.rankColor(rank)),
                  row(
                    'LOCK TARGETS',
                    '$lockTargets app${lockTargets == 1 ? '' : 's'}',
                  ),
                  row('REST', '${_hm(sleepStart)} – ${_hm(sleepEnd)}'),
                  row('FIRST QUEST', 'Today, 23:59'),
                  const SizedBox(height: 14),
                  Text(
                    'The first daily quest is active. The System is watching.',
                    style: Hud.mono(12, p.dim).copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  CutButton('ENTER', onPressed: onEnter),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers used elsewhere in the app

/// A task's target in words: "12 min", "1.5 km", "max 60 min", "once".
String questTarget(TaskDefinition t) => switch (t.type) {
  TaskType.checkbox => 'once',
  TaskType.timer || TaskType.phoneFree => '${t.target} min',
  TaskType.counter => '${t.target}',
  TaskType.distance => '${(t.target / 1000).toStringAsFixed(1)} km',
  TaskType.screenCap => 'max ${t.target} min',
};

/// What a System's penalty costs at level 1, in words.
String penaltyTerms(PenaltyKind kind) => switch (kind) {
  PenaltyKind.exercise => '50 push-ups (+5 per level, capped at 150; squats are added beyond the cap)',
  PenaltyKind.reading => '20 pages of reading (+2 per level, up to 60) and a written reflection on why the quest failed',
  PenaltyKind.focus => 'a 60-minute phone-free block (+5 minutes per level, up to 3 hours), run in the app with your chosen apps locked',
};

/// A System's penalty in a few words, for the System cards.
String penaltyShort(PenaltyKind kind) => switch (kind) {
  PenaltyKind.exercise => '50 push-ups',
  PenaltyKind.reading => '20 pages and a written reflection',
  PenaltyKind.focus => 'a 60-minute phone-free block',
};

/// A rank letter in its rank colour on the hexagonal badge.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 40});

  final Rank rank;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Rank ${rank.name.toUpperCase()}',
    child: CustomPaint(
      size: Size(size, size * 124 / 116),
      painter: RankHexPainter(rank),
    ),
  );
}
