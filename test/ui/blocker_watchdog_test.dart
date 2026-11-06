import 'dart:math';

import 'package:do_or_die/app/game_service.dart';
import 'package:do_or_die/app/penalty_enforcer.dart';
import 'package:do_or_die/data/game_store.dart';
import 'package:do_or_die/domain/clock.dart';
import 'package:do_or_die/domain/tasks.dart';
import 'package:do_or_die/platform/blocker.dart';
import 'package:do_or_die/ui/game_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone whose watcher can be stopped, as a force stop does.
class SwitchableBlocker extends NoopAppBlocker {
  @override
  bool get canBlock => true;

  bool serviceOn = true;
  bool canRepair = false;
  int repairAttempts = 0;
  DateTime? heartbeat;

  @override
  Future<SystemStatus> systemStatus() async => SystemStatus(
    serviceEnabled: serviceOn,
    batteryExempt: true,
    usageAccess: true,
    overlay: true,
    watcherRunning: serviceOn,
    lastHeartbeatAt: heartbeat,
  );

  @override
  Future<bool> startWatcher() async {
    repairAttempts++;
    if (canRepair) serviceOn = true;
    return serviceOn;
  }
}

const tasks = [
  TaskDefinition(id: 'read', name: 'Read', type: TaskType.counter, target: 30),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FixedClock clock;
  late SwitchableBlocker blocker;

  Future<GameModel> model() async {
    final service = await GameService.start(
      store: MemoryGameStore(),
      tasks: tasks,
      blockedPackages: const {'com.instagram.android'},
      clock: clock,
      random: Random(9),
    );
    final m = GameModel(
      service,
      enforcer: PenaltyEnforcer(blocker, clock: clock),
      pollEvery: null,
    );
    addTearDown(m.dispose);
    await m.tick();
    return m;
  }

  int incidents(GameModel m) =>
      m.service.game.log.where((e) => e.type == 'blocker_offline').length;

  setUp(() {
    clock = FixedClock(DateTime(2026, 10, 19, 10));
    blocker = SwitchableBlocker();
  });

  test(
    'with the service on, nothing is logged and no issue is shown',
    () async {
      final m = await model();
      expect(incidents(m), 0);
      expect(m.blockerOffline, isFalse);
    },
  );

  test('an outage is logged once, not on every check', () async {
    final m = await model();
    blocker.serviceOn = false; // e.g. the app was force-stopped
    await m.tick();
    await m.tick();
    await m.tick();
    expect(incidents(m), 1);
    expect(m.blockerOffline, isTrue);
    expect(m.service.blockerOfflineIncidents, 1);
  });

  test('a second outage after recovery is logged again', () async {
    final m = await model();
    blocker.serviceOn = false;
    await m.tick();
    blocker.serviceOn = true;
    await m.tick();
    blocker.serviceOn = false;
    await m.tick();
    expect(incidents(m), 2);
  });

  test(
    'a stopped watcher is restarted automatically, and the outage is logged',
    () async {
      final m = await model();
      blocker
        ..canRepair = true
        ..serviceOn = false;
      await m.tick();
      expect(blocker.repairAttempts, 1);
      expect(blocker.serviceOn, isTrue);
      expect(m.blockerOffline, isFalse);
      final entry = m.service.game.log.lastWhere(
        (e) => e.type == 'blocker_offline',
      );
      expect(entry.data['repaired'], isTrue);
    },
  );

  test('an outage during a penalty is flagged as such', () async {
    final m = await model();
    clock.set(DateTime(2026, 10, 20, 8)); // Monday failed: penalty today
    await m.tick();
    blocker.serviceOn = false;
    await m.tick();
    final entry = m.service.game.log.lastWhere(
      (e) => e.type == 'blocker_offline',
    );
    expect(entry.data['duringPenalty'], isTrue);
    expect(entry.data['repaired'], isFalse);
  });

  test(
    'a watcher that was only restarting is not counted as an outage',
    () async {
      final m = await model();
      blocker
        ..serviceOn = false
        ..canRepair = true
        ..heartbeat = clock.now().subtract(const Duration(seconds: 20));
      await m.tick();
      expect(incidents(m), 0);
      expect(blocker.repairAttempts, greaterThan(0));
    },
  );

  test('a real outage is logged with how long the watcher was down', () async {
    final m = await model();
    blocker
      ..serviceOn = false
      ..canRepair = true
      ..heartbeat = clock.now().subtract(const Duration(hours: 3));
    await m.tick();
    expect(incidents(m), 1);
    final e = m.service.game.log.lastWhere((e) => e.type == 'blocker_offline');
    expect(e.data['minutes'], 180);
    expect(e.data['duringLock'], isFalse);
  });
}
