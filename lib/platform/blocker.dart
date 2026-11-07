import 'package:flutter/services.dart';

class BlockerStatus {
  const BlockerStatus({
    required this.serviceEnabled,
    required this.locked,
    required this.lockStartsAt,
    required this.lockEndsAt,
    required this.blockedPackages,
    required this.needsJudgement,
    required this.lastConnectedAt,
    required this.lastDisconnectedAt,
    required this.blockCount,
    required this.lastBlockedPackage,
    required this.lastBlockAt,
    required this.emergencyStops,
    required this.judgeRedirects,
  });

  factory BlockerStatus.fromMap(Map<Object?, Object?> m) {
    DateTime? time(String key) {
      final v = (m[key] as num?)?.toInt() ?? 0;
      return v == 0 ? null : DateTime.fromMillisecondsSinceEpoch(v);
    }

    return BlockerStatus(
      serviceEnabled: m['serviceEnabled'] as bool? ?? false,
      locked: m['locked'] as bool? ?? false,
      lockStartsAt: time('lockStartsAt'),
      lockEndsAt: time('lockEndsAt'),
      blockedPackages: [
        for (final p in (m['blockedPackages'] as List?) ?? const [])
          p as String,
      ],
      needsJudgement: m['needsJudgement'] as bool? ?? false,
      lastConnectedAt: time('lastConnectedAt'),
      lastDisconnectedAt: time('lastDisconnectedAt'),
      blockCount: (m['blockCount'] as num?)?.toInt() ?? 0,
      lastBlockedPackage: m['lastBlockedPackage'] as String?,
      lastBlockAt: time('lastBlockAt'),
      emergencyStops: (m['emergencyStops'] as num?)?.toInt() ?? 0,
      judgeRedirects: (m['judgeRedirects'] as num?)?.toInt() ?? 0,
    );
  }

  final bool serviceEnabled;
  final bool locked;
  final DateTime? lockStartsAt;
  final DateTime? lockEndsAt;
  final List<String> blockedPackages;
  final bool needsJudgement;
  final DateTime? lastConnectedAt;
  final DateTime? lastDisconnectedAt;
  final int blockCount;
  final String? lastBlockedPackage;
  final DateTime? lastBlockAt;
  final int emergencyStops;
  final int judgeRedirects;
}

/// What the System Check reports about the phone.
class SystemStatus {
  const SystemStatus({
    this.serviceEnabled = false,
    this.usageAccess = false,
    this.overlay = false,
    this.watcherRunning = false,
    this.batteryExempt = false,
    this.autoTime = true,
    this.autoTimeZone = true,
    this.exactAlarms = true,
    this.watcherNeeded = false,
    this.lastHeartbeatAt,
  });

  factory SystemStatus.fromMap(Map<Object?, Object?> m) => SystemStatus(
    serviceEnabled: m['serviceEnabled'] as bool? ?? false,
    usageAccess: m['usageAccess'] as bool? ?? false,
    overlay: m['overlay'] as bool? ?? false,
    watcherRunning: m['watcherRunning'] as bool? ?? false,
    batteryExempt: m['batteryExempt'] as bool? ?? false,
    autoTime: m['autoTime'] as bool? ?? true,
    autoTimeZone: m['autoTimeZone'] as bool? ?? true,
    exactAlarms: m['exactAlarms'] as bool? ?? true,
    watcherNeeded: m['watcherNeeded'] as bool? ?? false,
    lastHeartbeatAt: switch (m['lastHeartbeatAt']) {
      final int ms when ms > 0 => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    },
  );

  /// Locks can be enforced: both permissions granted, and the watcher
  /// running whenever it is needed (it sleeps between exact alarms).
  final bool serviceEnabled;

  /// "Usage access": the watcher can see which app is in front.
  final bool usageAccess;

  /// "Display over other apps": the Penalty Zone can appear over a locked app.
  final bool overlay;

  /// The Penalty Zone watcher service is alive.
  final bool watcherRunning;

  /// Exempt from battery optimisation, so the OS won't stop the blocker.
  final bool batteryExempt;

  /// Automatic date and time is on.
  final bool autoTime;

  /// Automatic time zone is on.
  final bool autoTimeZone;

  /// Exact alarms are allowed, so the watcher can sleep and be woken on
  /// time; without them it runs all the time.
  final bool exactAlarms;

  /// The watcher has to be running right now.
  final bool watcherNeeded;

  /// When the watcher last reported in (every 10 s while it runs), so the
  /// length of an outage can be measured. Null if it never ran.
  final DateTime? lastHeartbeatAt;
}

/// What the block screen says during a lock.
enum LockMode {
  /// A failed daily quest.
  penalty,

  /// The day after a failed Dungeon floor: double lock, its own look.
  dungeon,
}

/// An installed app the user can choose to lock.
class InstalledApp {
  const InstalledApp(this.package, this.label, this.icon);

  final String package;
  final String label;

  /// PNG bytes, or null when unavailable.
  final Uint8List? icon;
}

/// Locks distracting apps. Android uses a usage-access watcher service; other
/// platforms get a stub until they have their own implementation.
abstract class AppBlocker {
  /// Whether this platform can actually lock apps (false on web).
  bool get canBlock;

  Future<BlockerStatus> status();

  /// The apps to lock during a penalty window.
  Future<void> setBlockedPackages(Set<String> packages);

  /// The scheduled penalty window. The start is never shown to the user.
  /// During a short release, apps open again until [releasedUntil];
  /// [releases] is how many have been taken, shown on the block screen.
  Future<void> setLockWindow(
    DateTime startsAt,
    DateTime endsAt, {
    DateTime? releasedUntil,
    int releases = 0,
    LockMode mode = LockMode.penalty,
  });
  Future<void> clearLockWindow();

  /// A phone-free block the user is running: the chosen apps stay locked
  /// until it is paused. Kept apart from the penalty window. Null clears it.
  Future<void> setFocusWindow(DateTime? startsAt, DateTime? endsAt);

  /// First day not yet judged, as yyyy-MM-dd. If it's before today, opening
  /// a locked app sends the user to Do or Die to get the verdict first.
  Future<void> setJudgeDueFrom(String isoDay);

  /// Launchable apps, excluding ones that must never be locked.
  Future<List<InstalledApp>> installedApps();

  /// Diagnostics: lock right now for [duration].
  Future<void> startLock(Duration duration);

  /// Diagnostics: end the lock now.
  Future<void> stopLock();

  Future<void> openAppSettings();

  Future<SystemStatus> systemStatus();
  Future<void> requestBatteryExemption();

  /// Opens the "Usage access" settings page.
  Future<void> requestUsageAccess();

  /// Opens the "Display over other apps" page for this app.
  Future<void> requestOverlay();

  /// Starts the watcher if its permissions are granted (it stops on a force
  /// stop). Returns whether locks can be enforced afterwards.
  Future<bool> startWatcher();

  /// No game any more: clears every lock, block, app and pending verdict on
  /// the phone and stops the watcher, so nothing keeps blocking.
  Future<void> reset();
}

/// Web and other platforms: no app blocking yet.
class NoopAppBlocker implements AppBlocker {
  @override
  bool get canBlock => false;

  @override
  Future<BlockerStatus> status() async => BlockerStatus.fromMap(const {});

  @override
  Future<void> setBlockedPackages(Set<String> packages) async {}

  @override
  Future<void> setLockWindow(
    DateTime startsAt,
    DateTime endsAt, {
    DateTime? releasedUntil,
    int releases = 0,
    LockMode mode = LockMode.penalty,
  }) async {}

  @override
  Future<void> clearLockWindow() async {}

  @override
  Future<void> setFocusWindow(DateTime? startsAt, DateTime? endsAt) async {}

  @override
  Future<void> setJudgeDueFrom(String isoDay) async {}

  @override
  Future<List<InstalledApp>> installedApps() async => const [];

  @override
  Future<void> startLock(Duration duration) async {}

  @override
  Future<void> stopLock() async {}

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<SystemStatus> systemStatus() async => const SystemStatus();

  @override
  Future<void> requestBatteryExemption() async {}

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<void> requestOverlay() async {}

  @override
  Future<bool> startWatcher() async => false;

  @override
  Future<void> reset() async {}
}

class AndroidAppBlocker implements AppBlocker {
  static const _channel = MethodChannel('doordie/blocker');

  @override
  bool get canBlock => true;

  @override
  Future<BlockerStatus> status() async => BlockerStatus.fromMap(
    await _channel.invokeMethod<Map<Object?, Object?>>('status') ?? const {},
  );

  @override
  Future<void> setBlockedPackages(Set<String> packages) => _channel
      .invokeMethod('setBlockedPackages', {'packages': packages.toList()});

  @override
  Future<void> setLockWindow(
    DateTime startsAt,
    DateTime endsAt, {
    DateTime? releasedUntil,
    int releases = 0,
    LockMode mode = LockMode.penalty,
  }) => _channel.invokeMethod('setLockWindow', {
    'startsAt': startsAt.millisecondsSinceEpoch,
    'endsAt': endsAt.millisecondsSinceEpoch,
    'releasedUntil': releasedUntil?.millisecondsSinceEpoch ?? 0,
    'releases': releases,
    'mode': mode.name,
  });

  @override
  Future<void> clearLockWindow() => _channel.invokeMethod('clearLockWindow');

  @override
  Future<void> setFocusWindow(DateTime? startsAt, DateTime? endsAt) =>
      _channel.invokeMethod('setFocusWindow', {
        'startsAt': startsAt?.millisecondsSinceEpoch ?? 0,
        'endsAt': endsAt?.millisecondsSinceEpoch ?? 0,
      });

  @override
  Future<void> setJudgeDueFrom(String isoDay) =>
      _channel.invokeMethod('setJudgeDueFrom', {'day': isoDay});

  @override
  Future<List<InstalledApp>> installedApps() async {
    final raw =
        await _channel.invokeMethod<List<Object?>>('installedApps') ?? const [];
    return [
      for (final item in raw.cast<Map<Object?, Object?>>())
        InstalledApp(
          item['package'] as String,
          item['label'] as String,
          item['icon'] as Uint8List?,
        ),
    ];
  }

  @override
  Future<void> startLock(Duration duration) =>
      _channel.invokeMethod('startLock', {'minutes': duration.inMinutes});

  @override
  Future<void> stopLock() => _channel.invokeMethod('stopLock');

  @override
  Future<void> openAppSettings() => _channel.invokeMethod('openAppSettings');

  @override
  Future<SystemStatus> systemStatus() async => SystemStatus.fromMap(
    await _channel.invokeMethod<Map<Object?, Object?>>('systemStatus') ??
        const {},
  );

  @override
  Future<void> requestBatteryExemption() =>
      _channel.invokeMethod('requestBatteryExemption');

  @override
  Future<void> requestUsageAccess() =>
      _channel.invokeMethod('requestUsageAccess');

  @override
  Future<void> requestOverlay() => _channel.invokeMethod('requestOverlay');

  @override
  Future<bool> startWatcher() async =>
      await _channel.invokeMethod<bool>('startWatcher') ?? false;

  @override
  Future<void> reset() => _channel.invokeMethod('reset');
}
