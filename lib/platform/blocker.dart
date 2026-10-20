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

/// An installed app the user can choose to lock.
class InstalledApp {
  const InstalledApp(this.package, this.label, this.icon);

  final String package;
  final String label;

  /// PNG bytes, or null when unavailable.
  final Uint8List? icon;
}

/// Locks distracting apps. Android uses an accessibility service; other
/// platforms get a stub until they have their own implementation.
abstract class AppBlocker {
  Future<BlockerStatus> status();

  /// The apps to lock during a penalty window.
  Future<void> setBlockedPackages(Set<String> packages);

  /// The scheduled penalty window. The start is never shown to the user.
  Future<void> setLockWindow(DateTime startsAt, DateTime endsAt);
  Future<void> clearLockWindow();

  /// First day not yet judged, as yyyy-MM-dd. If it's before today, opening
  /// a locked app sends the user to Do or Die to get the verdict first.
  Future<void> setJudgeDueFrom(String isoDay);

  /// Launchable apps, excluding ones that must never be locked.
  Future<List<InstalledApp>> installedApps();

  /// Diagnostics: lock right now for [duration].
  Future<void> startLock(Duration duration);

  /// Diagnostics: end the lock now.
  Future<void> stopLock();

  Future<void> openAccessibilitySettings();
  Future<void> openAppSettings();
}

/// Web and other platforms: no app blocking yet.
class NoopAppBlocker implements AppBlocker {
  @override
  Future<BlockerStatus> status() async => BlockerStatus.fromMap(const {});

  @override
  Future<void> setBlockedPackages(Set<String> packages) async {}

  @override
  Future<void> setLockWindow(DateTime startsAt, DateTime endsAt) async {}

  @override
  Future<void> clearLockWindow() async {}

  @override
  Future<void> setJudgeDueFrom(String isoDay) async {}

  @override
  Future<List<InstalledApp>> installedApps() async => const [];

  @override
  Future<void> startLock(Duration duration) async {}

  @override
  Future<void> stopLock() async {}

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> openAppSettings() async {}
}

class AndroidAppBlocker implements AppBlocker {
  static const _channel = MethodChannel('doordie/blocker');

  @override
  Future<BlockerStatus> status() async => BlockerStatus.fromMap(
    await _channel.invokeMethod<Map<Object?, Object?>>('status') ?? const {},
  );

  @override
  Future<void> setBlockedPackages(Set<String> packages) => _channel
      .invokeMethod('setBlockedPackages', {'packages': packages.toList()});

  @override
  Future<void> setLockWindow(DateTime startsAt, DateTime endsAt) =>
      _channel.invokeMethod('setLockWindow', {
        'startsAt': startsAt.millisecondsSinceEpoch,
        'endsAt': endsAt.millisecondsSinceEpoch,
      });

  @override
  Future<void> clearLockWindow() => _channel.invokeMethod('clearLockWindow');

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
  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');

  @override
  Future<void> openAppSettings() => _channel.invokeMethod('openAppSettings');
}
