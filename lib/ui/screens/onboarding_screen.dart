import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/penalty.dart';
import '../../domain/placement.dart';
import '../../domain/progression.dart';
import '../../domain/system_catalogue.dart';
import '../../domain/systems.dart';
import '../../domain/tasks.dart';
import '../../data/codec.dart';
import '../../platform/blocker.dart';
import 'app_picker_screen.dart';
import '../theme.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

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

/// The Awakening: the System appears, the user chooses a System, takes the
/// placement test, picks lock targets and a rest period, and accepts the
/// terms.
///
/// With [nextSystemOnly], only the System choice and placement are shown
/// (choosing the next System once the current one is complete); the lock
/// targets and sleep window in the result are then empty defaults.
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

enum _Step { intro, system, placement, verdict, apps, sleep, terms }

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final List<_Step> _steps = widget.nextSystemOnly
      ? const [_Step.system, _Step.placement, _Step.verdict]
      : _Step.values;
  int _index = 0;
  _Step get _step => _steps[_index];

  SystemKind? _system;
  final _answers = <String, int>{};
  TimeOfDay _sleepStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _sleepEnd = const TimeOfDay(hour: 7, minute: 0);
  String? _error;

  /// Apps the user picks to lock. Starts empty: nothing is chosen for them.
  final _blocked = <String>{};

  Rank get _placement => placementFor(_system!, _answers);

  void _next() {
    if (_step == _Step.system && _system == null) {
      return setState(() => _error = 'Choose a System.');
    }
    if (_step == _Step.sleep && _sleepStart == _sleepEnd) {
      return setState(() => _error = 'Sleep start and end must differ.');
    }
    if (_index == _steps.length - 1) return _finish();
    setState(() {
      _error = null;
      _index++;
    });
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _error = null;
      _index--;
    });
  }

  void _choose(SystemKind k) {
    setState(() {
      if (_system != k) _answers.clear();
      _system = k;
      _error = null;
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
        sleep: SleepWindow(
          startMinute: _sleepStart.hour * 60 + _sleepStart.minute,
          endMinute: _sleepEnd.hour * 60 + _sleepEnd.minute,
        ),
        blocked: {..._blocked},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final body = switch (_step) {
      _Step.intro => _intro(p),
      _Step.system => _systemStep(p),
      _Step.placement => _placementStep(p),
      _Step.verdict => _verdictStep(p),
      _Step.apps => _appStep(p),
      _Step.sleep => _sleepStep(p),
      _Step.terms => _termsStep(p),
    };
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 3,
                      color: i <= _index ? p.sys : p.sys.withValues(alpha: .15),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: ValueKey(_step),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                body,
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Hud.mono(12, Hud.warn),
                  ),
                ],
                if (_index > 0 && _step != _Step.intro) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _back,
                      child: Text('BACK', style: Hud.mono(11, p.dim)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lines(HudPalette p, List<String> lines) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: Hud.mono(13, p.text).copyWith(height: 1.5),
          ),
        ),
    ],
  );

  Widget _intro(HudPalette p) => SystemWindow(
    title: '[ SYSTEM ]',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _lines(p, const [
          'You have met the conditions to become a Player.',
          'The System will issue a daily quest. Clear it, and you grow.',
          'Fail it, and a penalty follows.',
          'Will you accept?',
        ]),
        const SizedBox(height: 6),
        HudButton('ACCEPT', onPressed: _next),
      ],
    ),
  );

  Widget _systemStep(HudPalette p) => SystemWindow(
    title: '[ CHOOSE YOUR SYSTEM ]',
    subtitle: widget.nextSystemOnly
        ? 'Your System is complete. Choose the next one.'
        : 'One System at a time. No switching until it is complete.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kind in SystemKind.values)
          if (!widget.completed.contains(kind))
            _SystemCard(
              spec: systemCatalogue[kind]!,
              selected: _system == kind,
              onTap: () => _choose(kind),
            ),
        const SizedBox(height: 6),
        HudButton('CONFIRM SYSTEM', onPressed: _next),
      ],
    ),
  );

  Widget _placementStep(HudPalette p) {
    final kind = _system!;
    return SystemWindow(
      title: '[ PLACEMENT TEST ]',
      subtitle: 'Answer honestly. The System sets your starting rank.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final q in placementQuestions[kind]!)
            _NumberField(
              key: ValueKey(q.id),
              question: q,
              value: _answers[q.id] ?? q.initial,
              onChanged: (v) => setState(() => _answers[q.id] = v),
            ),
          if (kind == SystemKind.focus && widget.yesterdaySocialMinutes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Read from usage access on this phone.',
                textAlign: TextAlign.center,
                style: Hud.mono(10, p.dim),
              ),
            ),
          const SizedBox(height: 6),
          HudButton('SUBMIT', onPressed: _next),
        ],
      ),
    );
  }

  Widget _verdictStep(HudPalette p) {
    final kind = _system!;
    final rank = _placement;
    final spec = systemCatalogue[kind]!;
    final quest = spec.at(rank).daily.map(questTask).toList();
    return SystemWindow(
      title: '[ RANK ASSIGNED ]',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: RankBadge(rank: rank, size: 64)),
          const SizedBox(height: 12),
          Text(
            '${spec.name.toUpperCase()} · RANK ${rank.name.toUpperCase()}',
            textAlign: TextAlign.center,
            style: Hud.head(15, p.hi, spacing: .12),
          ),
          const SizedBox(height: 14),
          Text(
            'DAILY QUEST',
            textAlign: TextAlign.center,
            style: Hud.mono(11, p.dim, spacing: .1),
          ),
          const SizedBox(height: 8),
          for (final t in quest)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('›  ', style: Hud.mono(12, p.sys)),
                  Expanded(child: Text(t.name, style: Hud.mono(12, p.text))),
                  Text(questTarget(t), style: Hud.mono(12, p.hi)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Ranks above C are earned only through Dungeons.',
            textAlign: TextAlign.center,
            style: Hud.mono(10, p.dim),
          ),
          if (kind == SystemKind.fitness) ...[
            const SizedBox(height: 6),
            Text(
              'These are conservative progressions, not medical advice. With a health condition, ask a doctor first.',
              textAlign: TextAlign.center,
              style: Hud.mono(10, Hud.warn),
            ),
          ],
          const SizedBox(height: 12),
          HudButton(
            widget.nextSystemOnly ? 'BEGIN THIS SYSTEM' : 'CONTINUE',
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  Widget _appStep(HudPalette p) => SystemWindow(
    title: '[ LOCK TARGETS ]',
    subtitle: 'Choose the apps that lock when you fail a day. Screen-time quests measure these apps.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 380,
          child: AppPickerList(
            blocker: widget.blocker,
            selected: _blocked,
            onChanged: (pkg, lock) =>
                setState(() => lock ? _blocked.add(pkg) : _blocked.remove(pkg)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _blocked.isEmpty
              ? 'No apps chosen yet. You can add them later from the Penalty tab.'
              : '${_blocked.length} app${_blocked.length == 1 ? '' : 's'} will lock on a failed day.',
          textAlign: TextAlign.center,
          style: Hud.mono(11, _blocked.isEmpty ? Hud.warn : p.dim),
        ),
        const SizedBox(height: 10),
        HudButton('CONFIRM APPS', onPressed: _next),
      ],
    ),
  );

  Widget _sleepStep(HudPalette p) => SystemWindow(
    title: '[ REST PERIOD ]',
    subtitle: 'Penalty locks never start or run while you sleep.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _timeRow(p, 'SLEEP STARTS', _sleepStart, (t) => _sleepStart = t),
        _timeRow(p, 'SLEEP ENDS', _sleepEnd, (t) => _sleepEnd = t),
        const SizedBox(height: 12),
        HudButton('CONFIRM', onPressed: _next),
      ],
    ),
  );

  Widget _timeRow(
    HudPalette p,
    String label,
    TimeOfDay value,
    ValueChanged<TimeOfDay> set,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: Hud.mono(12, p.dim, spacing: .08))),
        SizedBox(
          width: 110,
          child: HudButton(
            value.format(context),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: value,
              );
              if (picked != null) setState(() => set(picked));
            },
          ),
        ),
      ],
    ),
  );

  Widget _termsStep(HudPalette p) => SystemWindow(
    title: '[ PENALTY TERMS ]',
    subtitle: 'Read carefully. These rules are enforced.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in const [
          'If any objective is incomplete at midnight, the day is failed.',
          'The next day, chosen apps lock for 4 hours (+20 minutes per level), starting at an undisclosed time while you are awake.',
          'You also owe 50 push-ups (+5 per level, capped at 150; squats are added beyond the cap).',
          'Unpaid reps double and carry into the following day.',
          'Clear 21 of 30 days and a Gate opens. Enter it within 48 hours.',
          'A Dungeon is three floors on three days. Floor 2 must be cleared by 18:00. The third floor is the Rank Trial.',
          'Fail a floor and the Dungeon Penalty follows: double lock and double reps. The Gate stays shut for 7 days.',
          'Ranks never go down. One System at a time, until it is complete.',
          'A quest can be lowered by up to 20% for injury or illness, from the next day. Those days earn half XP.',
          'For the first 3 days, failures are a dry run: shown, never enforced.',
          'Calls, messages, maps and settings are never locked. Releases from a lock always exist, and every one is logged.',
          'Only do exercise that is safe for your body.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('›  ', style: Hud.mono(12, p.sys)),
                Expanded(
                  child: Text(
                    line,
                    style: Hud.mono(12, p.text).copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        HoldButton(
          label: 'HOLD TO ACCEPT',
          doneLabel: 'ACCEPTED',
          onConfirmed: _finish,
        ),
      ],
    ),
  );
}

/// A task's target in words: "12 min", "1.5 km", "max 60 min", "once".
String questTarget(TaskDefinition t) => switch (t.type) {
  TaskType.checkbox => 'once',
  TaskType.timer || TaskType.phoneFree => '${t.target} min',
  TaskType.counter => '${t.target}',
  TaskType.distance => '${(t.target / 1000).toStringAsFixed(1)} km',
  TaskType.screenCap => 'max ${t.target} min',
};

class _SystemCard extends StatelessWidget {
  const _SystemCard({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final SystemSpec spec;
  final bool selected;
  final VoidCallback onTap;

  static const _stat = {
    Stat.strength: 'STR',
    Stat.intellect: 'INT',
    Stat.discipline: 'DIS',
    Stat.vitality: 'VIT',
    Stat.charisma: 'CHA',
  };

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        label: spec.name,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? p.sys.withValues(alpha: .16)
                  : Colors.transparent,
              border: Border.all(color: selected ? p.sys : p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spec.name.toUpperCase(),
                        style: Hud.head(
                          14,
                          selected ? p.hi : p.text,
                          spacing: .12,
                        ),
                      ),
                    ),
                    Text(
                      spec.stats.map((s) => _stat[s]).join(' · '),
                      style: Hud.mono(11, p.sys),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(spec.tagline, style: Hud.mono(11, p.dim)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    super.key,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final PlacementQuestion question;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _c = TextEditingController(text: '${widget.value}');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _set(int v) {
    final q = widget.question;
    final clamped = v.clamp(q.min, q.max);
    _c.text = '$clamped';
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final q = widget.question;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(q.prompt, style: Hud.mono(12, p.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 44,
                child: HudButton(
                  '−',
                  semanticLabel: 'Decrease',
                  onPressed: () => _set(widget.value - 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: q.prompt,
                  child: TextField(
                    controller: _c,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: Hud.mono(15, p.hi),
                    cursorColor: p.sys,
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: q.unit,
                      suffixStyle: Hud.mono(10, p.dim),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: p.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: p.sys),
                      ),
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null) widget.onChanged(n.clamp(q.min, q.max));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: HudButton(
                  '+',
                  semanticLabel: 'Increase',
                  onPressed: () => _set(widget.value + 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A rank letter in its rank colour, framed like a System badge.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 40});

  final Rank rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Hud.rankColor(rank);
    return Semantics(
      label: 'Rank ${rank.name.toUpperCase()}',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.5),
          color: c.withValues(alpha: .1),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: .35), blurRadius: 14),
          ],
        ),
        child: Text(
          rank.name.toUpperCase(),
          style: Hud.head(size * .5, c, spacing: 0),
        ),
      ),
    );
  }
}
