import 'package:flutter/material.dart';

import '../../platform/blocker.dart';
import '../game_model.dart';
import '../theme.dart';
import '../widgets/hud_background.dart';
import '../widgets/hud_controls.dart';
import '../widgets/system_window.dart';

/// Searchable list of installed apps with a lock toggle on each.
class AppPickerList extends StatefulWidget {
  const AppPickerList({
    super.key,
    required this.blocker,
    required this.selected,
    required this.onChanged,
    this.pending = const {},
  });

  final AppBlocker blocker;
  final Set<String> selected;

  /// Selected apps that unlock from tomorrow (removal is not immediate).
  final Set<String> pending;
  final void Function(String package, bool lock) onChanged;

  @override
  State<AppPickerList> createState() => _AppPickerListState();
}

class _AppPickerListState extends State<AppPickerList> {
  late final Future<List<InstalledApp>> _apps = widget.blocker.installedApps();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    return FutureBuilder<List<InstalledApp>>(
      future: _apps,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(
            child: Text(
              'SCANNING APPS…',
              style: Hud.mono(12, p.dim, spacing: .14),
            ),
          );
        }
        final all = snap.data ?? const [];
        if (all.isEmpty) {
          return Center(
            child: Text(
              'No apps found on this device.',
              style: Hud.mono(12, p.dim),
            ),
          );
        }
        final q = _query.trim().toLowerCase();
        final shown =
            [
              for (final a in all)
                if (q.isEmpty || a.label.toLowerCase().contains(q)) a,
            ]..sort((a, b) {
              // Chosen apps first, then alphabetical.
              final sa = widget.selected.contains(a.package) ? 0 : 1;
              final sb = widget.selected.contains(b.package) ? 0 : 1;
              return sa != sb
                  ? sa - sb
                  : a.label.toLowerCase().compareTo(b.label.toLowerCase());
            });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Search apps',
              child: TextField(
                style: Hud.mono(13, p.text),
                cursorColor: p.sys,
                decoration: InputDecoration(
                  hintText: 'Search apps',
                  hintStyle: Hud.mono(12, p.dim),
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18, color: p.dim),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: p.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: p.sys),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) =>
                    Container(height: 1, color: p.sys.withValues(alpha: .08)),
                itemBuilder: (context, i) {
                  final app = shown[i];
                  final locked = widget.selected.contains(app.package);
                  final pending = widget.pending.contains(app.package);
                  return _AppRow(
                    app: app,
                    locked: locked,
                    pending: pending,
                    onTap: () =>
                        widget.onChanged(app.package, !locked || pending),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.locked,
    required this.pending,
    required this.onTap,
  });

  final InstalledApp app;
  final bool locked;
  final bool pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = HudScope.of(context);
    final on = locked && !pending;
    return Semantics(
      container: true,
      toggled: on,
      label: '${app.label}${pending ? ', unlocks in 7 days' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: app.icon == null
                    ? Icon(Icons.apps, color: p.dim)
                    : Image.memory(app.icon!, gaplessPlayback: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.label,
                        style: Hud.mono(13, on ? p.text : p.dim),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pending)
                        Text(
                          'UNLOCKS IN 7 DAYS',
                          style: Hud.mono(9, Hud.warn, spacing: .12),
                        ),
                    ],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on
                      ? HudPalette.penalty.sys.withValues(alpha: .18)
                      : Colors.transparent,
                  border: Border.all(
                    color: on ? HudPalette.penalty.sys : p.line,
                  ),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    on ? 'LOCK' : 'OFF',
                    style: Hud.mono(
                      10,
                      on ? HudPalette.penalty.hi : p.dim,
                      spacing: .12,
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

/// Full screen for changing the locked apps after onboarding.
class AppPickerScreen extends StatelessWidget {
  const AppPickerScreen({
    super.key,
    required this.model,
    required this.blocker,
  });

  final GameModel model;
  final AppBlocker blocker;

  @override
  Widget build(BuildContext context) {
    return HudScope(
      palette: HudPalette.system,
      child: Scaffold(
        body: HudBackground(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SystemWindow(
                        expand: true,
                        title: '[ LOCK TARGETS ]',
                        subtitle: 'Adding an app locks it from now. Removing one takes effect in 7 days; at least one app stays.',
                        child: AppPickerList(
                          blocker: blocker,
                          selected: model.service.blockedToday,
                          pending: model.pendingUnblocks,
                          onChanged: (pkg, lock) async {
                            if (lock) {
                              await model.addBlockedApp(pkg);
                            } else if (!await model.removeBlockedApp(pkg) &&
                                context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'At least one app must stay on the lock list.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    HudButton(
                      'DONE',
                      onPressed: () => Navigator.of(context).pop(),
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
