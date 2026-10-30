import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../app/notification_planner.dart';

/// Schedules System notices with the OS, so they arrive with the app closed.
abstract class Notifier {
  Future<void> init();

  /// Asks for permission (Android 13+). Returns whether notices may be shown.
  Future<bool> requestPermission();

  Future<bool> isPermitted();

  /// Whether notices can fire at their exact time. Without this, Android may
  /// deliver them up to an hour late.
  Future<bool> canBeExact();

  /// Opens the "Alarms & reminders" setting for this app.
  Future<void> requestExact();

  /// Makes the scheduled notices match [plan] exactly.
  Future<void> apply(List<PlannedNotice> plan);
}

class NoopNotifier implements Notifier {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> isPermitted() async => false;

  @override
  Future<bool> canBeExact() async => false;

  @override
  Future<void> requestExact() async {}

  @override
  Future<void> apply(List<PlannedNotice> plan) async {}
}

class LocalNotifier implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// What is currently scheduled, by id, so unchanged notices aren't re-sent.
  final _scheduled = <int, PlannedNotice>{};

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'system_notices',
      'System notices',
      channelDescription: 'Deadline warnings, verdicts and penalty alerts.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Old zone names some phones still report, mapped to the names in the
  /// timezone database (Android reports "Asia/Calcutta" in India).
  static String _canonical(String id) =>
      const {
        'Asia/Calcutta': 'Asia/Kolkata',
        'Asia/Katmandu': 'Asia/Kathmandu',
        'Asia/Saigon': 'Asia/Ho_Chi_Minh',
        'Asia/Rangoon': 'Asia/Yangon',
      }[id] ??
      id;

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(_canonical(zone.identifier)));
    } catch (e) {
      debugPrint('Timezone lookup failed, using UTC offset clock: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    // A fresh start knows nothing about earlier schedules; clear them so the
    // first apply() is the single source of truth.
    await _plugin.cancelAll();
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<bool> isPermitted() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> canBeExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  @override
  Future<void> requestExact() async {
    await _android?.requestExactAlarmsPermission();
  }

  /// The mode the current schedule was made with; a change re-schedules all.
  AndroidScheduleMode? _mode;

  @override
  Future<void> apply(List<PlannedNotice> plan) async {
    if (!_ready) return;
    final mode = await canBeExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    if (mode != _mode) {
      _scheduled.clear(); // forces every notice to be re-sent in the new mode
      _mode = mode;
    }
    final wanted = {for (final n in plan) n.id: n};
    for (final id in _scheduled.keys.toList()) {
      if (!wanted.containsKey(id)) {
        await _plugin.cancel(id: id);
        _scheduled.remove(id);
      }
    }
    for (final n in plan) {
      if (_scheduled[n.id] == n) continue;
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: mode,
        title: n.title,
        body: n.body,
      );
      _scheduled[n.id] = n;
    }
  }
}
