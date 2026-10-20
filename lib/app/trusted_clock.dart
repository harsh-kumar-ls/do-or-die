import '../domain/clock.dart';
import '../platform/time_source.dart';

/// The device clock, corrected by network time whenever the phone has it.
///
/// Changing the phone's clock in Settings therefore can't reopen a judged day
/// or shorten a lock. Without network time, it falls back to the device clock
/// (keeping the last known correction) and says so via [isNetworkBacked].
class TrustedClock implements Clock {
  TrustedClock(this.source);

  final TimeSource source;

  Duration _offset = Duration.zero;
  bool _networkBacked = false;
  bool _autoTime = true;

  /// Differences smaller than this are normal clock drift, not tampering.
  static const _ignoreBelow = Duration(seconds: 2);

  @override
  DateTime now() => DateTime.now().add(_offset);

  /// True once a network reading has set the correction.
  bool get isNetworkBacked => _networkBacked;

  /// False when the user turned off automatic date and time.
  bool get autoTime => _autoTime;

  /// How far the phone's own clock is from trusted time.
  Duration get deviceOffset => _offset;

  Future<void> refresh() async {
    final reading = await source.read();
    _autoTime = reading.autoTime;
    final network = reading.network;
    if (network == null) return; // keep the last known correction
    final offset = network.difference(reading.device);
    _offset = offset.abs() < _ignoreBelow ? Duration.zero : offset;
    _networkBacked = true;
  }
}
