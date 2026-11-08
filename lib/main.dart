import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/game_service.dart';
import 'app/penalty_enforcer.dart';
import 'app/trusted_clock.dart';
import 'data/game_store.dart';
import 'platform/blocker.dart';
import 'platform/notifier.dart';
import 'platform/share_file.dart';
import 'platform/time_source.dart';
import 'platform/usage_meter.dart';
import 'ui/app_shell.dart';
import 'ui/fx.dart';
import 'ui/game_model.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/hud_background.dart';

/// Platform services: real ones on Android, stand-ins elsewhere (web, tests).
class Platform {
  Platform._(this.blocker, this.notifier, this.clock, this.meter);

  factory Platform.current() {
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return android
        ? Platform._(
            AndroidAppBlocker(),
            LocalNotifier(),
            TrustedClock(AndroidTimeSource()),
            const AndroidUsageMeter(),
          )
        : Platform._(
            NoopAppBlocker(),
            NoopNotifier(),
            TrustedClock(const DeviceTimeSource()),
            const NoUsageMeter(),
          );
  }

  final AppBlocker blocker;
  final Notifier notifier;
  final TrustedClock clock;
  final UsageMeter meter;
}

/// The phone's IANA time zone ("Europe/Berlin"), or null if unreadable.
Future<String?> phoneZoneId() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return null;
  }
}

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Flutter web draws to a canvas; the semantics tree gives screen readers
  // and browser test agents real, labelled elements to work with.
  if (kIsWeb) binding.ensureSemantics();
  final prefs = SharedPreferencesAsync();
  // Sounds load in the background; until then (or if audio fails) the app is
  // silent but haptics still work.
  unawaited(Fx.instance.init(prefs));

  final platform = Platform.current();
  // Read trusted time before any day is judged, so a changed phone clock
  // can't affect the first verdict.
  try {
    await platform.clock.refresh();
  } catch (e) {
    debugPrint('Trusted time unavailable at start: $e');
  }
  try {
    await platform.notifier.init();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }

  final store = PrefsGameStore(prefs);
  GameService? service;
  try {
    service = await GameService.load(
      store: store,
      clock: platform.clock,
      meter: platform.meter,
      zoneId: phoneZoneId,
    );
    // A trial with its own written objectives is archived, with its full log,
    // and replaced by an Awakening. One with a penalty still in effect is kept
    // until that penalty is over, so the update is never a way out of one.
    if (service != null && service.needsMigration) {
      if (await service.abandon(reason: 'migrated_to_systems')) {
        // The old game is gone: nothing may keep blocking for it.
        await platform.blocker.reset();
        service = null;
      }
    }
  } catch (e, st) {
    // Never fall through to a fresh start silently: that could wipe a game
    // (and a penalty). Say what went wrong, and let the user export the save
    // and, deliberately, start again.
    debugPrint('Could not load the saved game: $e\n$st');
    runApp(
      StartupErrorApp(
        error: '$e',
        onExport: () async {
          final raw = await store.raw();
          if (raw != null) {
            await shareTextFile(raw, name: 'do-or-die-save.json');
          }
        },
        onReset: () async {
          await store.setAsideUnreadable();
          await platform.blocker.reset();
          await SystemNavigator.pop();
        },
      ),
    );
    return;
  }
  runApp(DoOrDieApp(store: store, initial: service, platform: platform));
}

class DoOrDieApp extends StatefulWidget {
  const DoOrDieApp({
    super.key,
    required this.store,
    required this.initial,
    required this.platform,
  });

  final GameStore store;
  final GameService? initial;
  final Platform platform;

  @override
  State<DoOrDieApp> createState() => _DoOrDieAppState();
}

class _DoOrDieAppState extends State<DoOrDieApp> {
  GameModel? _model;
  late final _enforcer = PenaltyEnforcer(
    widget.platform.blocker,
    clock: widget.platform.clock,
  );

  GameModel _modelFor(GameService service) => GameModel(
    service,
    enforcer: _enforcer,
    notifier: widget.platform.notifier,
    trustedClock: widget.platform.clock,
  );

  /// Whether the next Awakening gets the 3-day dry run (once per install).
  bool _dryRunAvailable = true;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _model = _modelFor(widget.initial!);
    widget.store.dryRunUsed().then((used) {
      if (mounted) setState(() => _dryRunAvailable = !used);
    });
  }

  @override
  void dispose() {
    _model?.dispose();
    super.dispose();
  }

  Future<void> _onboard(OnboardingResult r) async {
    // One dry run per install: restarting never grants another.
    final dryRun = !await widget.store.dryRunUsed();
    final service = await GameService.awaken(
      store: widget.store,
      system: r.system,
      placement: r.placement,
      placementAnswers: r.answers,
      blockedPackages: r.blocked,
      sleep: r.sleep,
      dryRunDays: dryRun ? 3 : 0,
      // No dry run: the first live quest starts tomorrow.
      startTomorrow: !dryRun,
      clock: widget.platform.clock,
      meter: widget.platform.meter,
      zoneId: phoneZoneId,
    );
    await widget.store.markDryRunUsed();
    final model = _modelFor(service);
    setState(() => _model = model);
    // Ask once registration is done, when the reason is obvious.
    await model.requestNotifications();
  }

  /// The game was archived and removed: back to the Awakening. The phone's
  /// blocker is cleared, so no lock or verdict redirect outlives the game.
  Future<void> _abandoned() async {
    final old = _model;
    setState(() => _model = null);
    old?.dispose();
    await _enforcer.reset();
    final used = await widget.store.dryRunUsed();
    if (mounted) setState(() => _dryRunAvailable = !used);
  }

  @override
  Widget build(BuildContext context) {
    final model = _model;
    final blocker = widget.platform.blocker;
    return MaterialApp(
      title: 'Do or Die',
      debugShowCheckedModeBanner: false,
      theme: Hud.theme(HudPalette.system),
      home: model == null
          ? HudScope(
              palette: HudPalette.system,
              child: Scaffold(
                body: HudBackground(
                  child: OnboardingScreen(
                    blocker: blocker,
                    onDone: _onboard,
                    dryRun: _dryRunAvailable,
                  ),
                ),
              ),
            )
          : AppShell(
              key: ObjectKey(model),
              model: model,
              blocker: blocker,
              onAbandoned: _abandoned,
            ),
    );
  }
}

/// Shown when the saved game can't be read at start.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({
    super.key,
    required this.error,
    this.onExport,
    this.onReset,
  });

  final String error;

  /// Shares the unreadable save as a file.
  final Future<void> Function()? onExport;

  /// Sets the unreadable save aside (kept, never deleted), clears the
  /// phone's blocker and closes the app; the next start is a new Awakening.
  final Future<void> Function()? onReset;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: Hud.theme(HudPalette.penalty),
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '[ SYSTEM ERROR ]',
                style: Hud.head(18, HudPalette.penalty.hi),
              ),
              const SizedBox(height: 16),
              Text(
                'The saved game could not be read. Nothing has been changed. '
                'Restart the app; if this persists, report the text below.',
                textAlign: TextAlign.center,
                style: Hud.mono(13, HudPalette.penalty.text),
              ),
              const SizedBox(height: 16),
              SelectableText(
                error,
                style: Hud.mono(11, HudPalette.penalty.dim),
              ),
              const SizedBox(height: 24),
              if (onExport != null)
                OutlinedButton(
                  onPressed: onExport,
                  child: const Text('EXPORT SAVED DATA'),
                ),
              if (onReset != null) ...[
                const SizedBox(height: 12),
                _ResetButton(onReset: onReset!),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Starting again needs a confirmation: the unreadable save is kept aside,
/// but the current game can't be continued afterwards.
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onReset});

  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Start again?'),
          content: const Text(
            'The unreadable save is kept on this phone and can still be '
            'exported. A new Awakening starts the next time the app opens. '
            'Any lock from the old game is cleared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('START AGAIN'),
            ),
          ],
        ),
      );
      if (ok == true) await onReset();
    },
    child: const Text('START AGAIN'),
  );
}
