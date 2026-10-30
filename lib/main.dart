import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/game_service.dart';
import 'app/penalty_enforcer.dart';
import 'app/trusted_clock.dart';
import 'data/game_store.dart';
import 'platform/blocker.dart';
import 'platform/notifier.dart';
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
    );
    // A trial with its own written objectives is archived, with its full log,
    // and replaced by an Awakening. One with a penalty still in effect is kept
    // until that penalty is over, so the update is never a way out of one.
    if (service != null && service.needsMigration) {
      if (await service.abandon(reason: 'migrated_to_systems')) service = null;
    }
  } catch (e, st) {
    // Never fall through to a fresh start: that could wipe a game (and a
    // penalty). Say what went wrong instead of hanging on a black screen.
    debugPrint('Could not load the saved game: $e\n$st');
    runApp(StartupErrorApp(error: '$e'));
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

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _model = _modelFor(widget.initial!);
  }

  @override
  void dispose() {
    _model?.dispose();
    super.dispose();
  }

  Future<void> _onboard(OnboardingResult r) async {
    final service = await GameService.awaken(
      store: widget.store,
      system: r.system,
      placement: r.placement,
      placementAnswers: r.answers,
      blockedPackages: r.blocked,
      sleep: r.sleep,
      dryRunDays: 3,
      clock: widget.platform.clock,
      meter: widget.platform.meter,
    );
    final model = _modelFor(service);
    setState(() => _model = model);
    // Ask once registration is done, when the reason is obvious.
    await model.requestNotifications();
  }

  /// The game was archived and removed: back to the Awakening.
  void _abandoned() {
    final old = _model;
    setState(() => _model = null);
    old?.dispose();
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
                  child: OnboardingScreen(blocker: blocker, onDone: _onboard),
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
  const StartupErrorApp({super.key, required this.error});

  final String error;

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
                style: Hud.mono(10, HudPalette.penalty.dim),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
