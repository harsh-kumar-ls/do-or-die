import 'package:flutter/services.dart';

/// One reading of the phone's clocks.
class TimeReading {
  const TimeReading({required this.device, this.network, this.autoTime = true});

  /// The phone's own clock, which the user can change.
  final DateTime device;

  /// Network-synced time the user can't change, if the phone has a fix.
  final DateTime? network;

  /// Whether "Set time automatically" is on.
  final bool autoTime;
}

abstract class TimeSource {
  Future<TimeReading> read();
  Future<void> openDateSettings();
}

/// Web, tests: the device clock is all there is.
class DeviceTimeSource implements TimeSource {
  const DeviceTimeSource();

  @override
  Future<TimeReading> read() async => TimeReading(device: DateTime.now());

  @override
  Future<void> openDateSettings() async {}
}

class AndroidTimeSource implements TimeSource {
  static const _channel = MethodChannel('doordie/blocker');

  @override
  Future<TimeReading> read() async {
    final m =
        await _channel.invokeMethod<Map<Object?, Object?>>('trustedTime') ??
        const {};
    final network = (m['network'] as num?)?.toInt();
    return TimeReading(
      device: DateTime.fromMillisecondsSinceEpoch(
        (m['device'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      network: network == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(network),
      autoTime: m['autoTime'] as bool? ?? true,
    );
  }

  @override
  Future<void> openDateSettings() => _channel.invokeMethod('openDateSettings');
}
