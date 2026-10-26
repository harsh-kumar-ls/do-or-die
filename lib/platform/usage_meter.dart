import 'package:flutter/services.dart';

/// Measures how long apps were in the foreground, for screen-time caps.
abstract class UsageMeter {
  /// Minutes [packages] were in front between [from] and [to], or null when
  /// it can't be measured (no usage access, or not Android).
  Future<int?> minutesUsed(Set<String> packages, DateTime from, DateTime to);
}

class NoUsageMeter implements UsageMeter {
  const NoUsageMeter();

  @override
  Future<int?> minutesUsed(
    Set<String> packages,
    DateTime from,
    DateTime to,
  ) async => null;
}

/// Reads Android's usage events (the same usage access the watcher uses).
class AndroidUsageMeter implements UsageMeter {
  const AndroidUsageMeter();

  static const _channel = MethodChannel('doordie/blocker');

  @override
  Future<int?> minutesUsed(
    Set<String> packages,
    DateTime from,
    DateTime to,
  ) async {
    try {
      return await _channel.invokeMethod<int>('minutesUsed', {
        'packages': packages.toList(),
        'from': from.millisecondsSinceEpoch,
        'to': to.millisecondsSinceEpoch,
      });
    } on PlatformException {
      return null;
    }
  }
}
