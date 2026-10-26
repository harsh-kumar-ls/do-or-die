import 'package:flutter/material.dart';

import '../../domain/penalty.dart';
import '../../domain/tasks.dart';
import '../../platform/blocker.dart';
import 'app_picker_screen.dart';
import '../theme.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

class OnboardingResult {
  const OnboardingResult(this.tasks, this.sleep, this.blocked);
  final List<TaskDefinition> tasks;
  final SleepWindow sleep;
  final Set<String> blocked;
}

/// First run: registration notice, the user writes their tasks, sets their
/// sleep window, and accepts the penalty rules.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.blocker,
    required this.onDone,
  });

  final AppBlocker blocker;
  final ValueChanged<OnboardingResult> onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Draft {
  _Draft(this.name, this.type, this.target);
  String name;
  TaskType type;
  int target;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final _tasks = <_Draft>[
    _Draft('Have breakfast', TaskType.checkbox, 1),
    _Draft('Study', TaskType.timer, 120),
    _Draft('Read', TaskType.counter, 30),
  ];
  TimeOfDay _sleepStart = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _sleepEnd = const TimeOfDay(hour: 7, minute: 0);
  String? _error;

  /// Apps the user picks to lock. Starts empty: nothing is chosen for them.
  final _blocked = <String>{};

  void _next() {
    if (_step == 1) {
      final names = _tasks.map((t) => t.name.trim()).toList();
      final error = _tasks.isEmpty
          ? 'Add at least one task.'
          : names.any((n) => n.isEmpty)
          ? 'Every task needs a name.'
          : _tasks.any((t) => t.target <= 0)
          ? 'Every target must be above zero.'
          : null;
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }
    if (_step == 3 && _sleepStart == _sleepEnd) {
      return setState(() => _error = 'Sleep start and end must differ.');
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _finish() {
    final used = <String>{};
    String idFor(String name) {
      var base = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
      if (base.isEmpty) base = 'task';
      var id = base;
      for (var n = 2; used.contains(id); n++) {
        id = '${base}_$n';
      }
      used.add(id);
      return id;
    }

    widget.onDone(
      OnboardingResult(
        [
          for (final t in _tasks)
            TaskDefinition(
              id: idFor(t.name),
              name: t.name.trim(),
              type: t.type,
              target: t.target,
            ),
        ],
        SleepWindow(
          startMinute: _sleepStart.hour * 60 + _sleepStart.minute,
          endMinute: _sleepEnd.hour * 60 + _sleepEnd.minute,
        ),
        {..._blocked},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final steps = [_intro, _taskStep, _appStep, _sleepStep, _consentStep];
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 3,
                      color: i <= _step ? p.sys : p.sys.withValues(alpha: .15),
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
                steps[_step](p),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Hud.mono(12, Hud.warn),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(HudPalette p) => SystemWindow(
    title: '[ SYSTEM ]',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in [
          'Candidate detected.',
          'From today, a daily quest will be issued at midnight.',
          'Clear it, and you grow stronger.',
          'Fail it, and a penalty follows.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              line,
              textAlign: TextAlign.center,
              style: Hud.mono(13, p.text).copyWith(height: 1.5),
            ),
          ),
        const SizedBox(height: 6),
        HudButton('BEGIN REGISTRATION', onPressed: _next),
      ],
    ),
  );

  Widget _taskStep(HudPalette p) => SystemWindow(
    title: '[ DAILY QUEST ]',
    subtitle: 'Write your own objectives. You know your limits.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, t) in _tasks.indexed)
          _TaskEditor(
            key: ObjectKey(t),
            draft: t,
            onChanged: () => setState(() {}),
            onRemove: _tasks.length > 1
                ? () => setState(() => _tasks.removeAt(i))
                : null,
          ),
        if (_tasks.length < 5)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: HudButton(
              '+ ADD OBJECTIVE',
              onPressed: () =>
                  setState(() => _tasks.add(_Draft('', TaskType.checkbox, 1))),
            ),
          ),
        HudButton('CONFIRM OBJECTIVES', onPressed: _next),
      ],
    ),
  );

  Widget _appStep(HudPalette p) => SystemWindow(
    title: '[ LOCK TARGETS ]',
    subtitle: 'Choose the apps that lock when you fail a day.',
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

  Widget _consentStep(HudPalette p) => SystemWindow(
    title: '[ PENALTY TERMS ]',
    subtitle: 'Read carefully. These rules are enforced.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in [
          'If any objective is incomplete at midnight, the day is failed.',
          'The next day, chosen apps lock for 4 hours (+20 minutes per level), starting at an undisclosed time while you are awake.',
          'You also owe 50 push-ups (+5 per level, capped at 150; squats are added beyond the cap).',
          'Unpaid reps double and carry into the following day.',
          'Calls, messages, maps and settings are never locked. An emergency exit always exists, and every use is logged.',
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

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    this.onRemove,
  });

  final _Draft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _name = TextEditingController(text: widget.draft.name);
  late final _target = TextEditingController(text: '${widget.draft.target}');

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  InputDecoration _deco(HudPalette p, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: Hud.mono(12, p.dim),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: p.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: p.sys),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final d = widget.draft;
    final unit = switch (d.type) {
      TaskType.checkbox => 'once',
      TaskType.timer => 'minutes',
      TaskType.counter => 'count',
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Objective name',
                  child: TextField(
                    controller: _name,
                    style: Hud.mono(13, p.text),
                    cursorColor: p.sys,
                    decoration: _deco(p, 'Objective name'),
                    onChanged: (v) {
                      d.name = v;
                      widget.onChanged();
                    },
                  ),
                ),
              ),
              if (widget.onRemove != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: HudButton(
                    '×',
                    semanticLabel: 'Remove objective',
                    onPressed: widget.onRemove,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final type in const [
                TaskType.checkbox,
                TaskType.timer,
                TaskType.counter,
              ]) ...[
                Expanded(
                  child: _TypeChip(
                    label: switch (type) {
                      TaskType.checkbox => 'CHECK',
                      TaskType.timer => 'TIMER',
                      TaskType.counter => 'COUNT',
                      _ => '',
                    },
                    selected: d.type == type,
                    onTap: () {
                      d.type = type;
                      if (type == TaskType.checkbox) {
                        d.target = 1;
                        _target.text = '1';
                      }
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 6),
              ],
              SizedBox(
                width: 84,
                child: Semantics(
                  label: 'Target $unit',
                  child: TextField(
                    controller: _target,
                    enabled: d.type != TaskType.checkbox,
                    keyboardType: TextInputType.number,
                    style: Hud.mono(13, p.text),
                    cursorColor: p.sys,
                    decoration: _deco(p, unit).copyWith(
                      suffixText: d.type == TaskType.checkbox
                          ? null
                          : unit == 'minutes'
                          ? 'min'
                          : null,
                      suffixStyle: Hud.mono(10, p.dim),
                    ),
                    onChanged: (v) {
                      d.target = int.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.sys.withValues(alpha: .18) : Colors.transparent,
          border: Border.all(color: selected ? p.sys : p.line),
        ),
        child: Text(
          label,
          style: Hud.mono(10, selected ? p.hi : p.dim, spacing: .1),
        ),
      ),
    );
  }
}
