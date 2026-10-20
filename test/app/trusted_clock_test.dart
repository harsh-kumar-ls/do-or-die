import 'package:do_or_die/app/trusted_clock.dart';
import 'package:do_or_die/platform/time_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone whose own clock is [deviceSkew] away from real (network) time.
class FakeTimeSource implements TimeSource {
  Duration deviceSkew = Duration.zero;
  bool hasNetwork = true;
  bool autoTime = true;

  @override
  Future<TimeReading> read() async {
    final real = DateTime.now();
    return TimeReading(
      device: real.add(deviceSkew),
      network: hasNetwork ? real : null,
      autoTime: autoTime,
    );
  }

  @override
  Future<void> openDateSettings() async {}
}

void main() {
  test(
    'with network time, a phone clock set back 3 hours is corrected',
    () async {
      final source = FakeTimeSource()..deviceSkew = const Duration(hours: -3);
      final clock = TrustedClock(source);
      await clock.refresh();
      expect(clock.isNetworkBacked, isTrue);
      expect(clock.deviceOffset.inMinutes, 180);
    },
  );

  test('normal drift under 2 seconds is ignored', () async {
    final source = FakeTimeSource()
      ..deviceSkew = const Duration(milliseconds: 800);
    final clock = TrustedClock(source);
    await clock.refresh();
    expect(clock.deviceOffset, Duration.zero);
  });

  test('without network time, the last known correction is kept', () async {
    final source = FakeTimeSource()..deviceSkew = const Duration(hours: -1);
    final clock = TrustedClock(source);
    await clock.refresh();
    source
      ..hasNetwork = false
      ..deviceSkew = const Duration(hours: -5);
    await clock.refresh();
    expect(clock.deviceOffset.inMinutes, 60);
  });

  test(
    'never having network time means the device clock, flagged as such',
    () async {
      final source = FakeTimeSource()..hasNetwork = false;
      final clock = TrustedClock(source);
      await clock.refresh();
      expect(clock.isNetworkBacked, isFalse);
      expect(clock.deviceOffset, Duration.zero);
    },
  );

  test('automatic date and time being off is reported', () async {
    final source = FakeTimeSource()..autoTime = false;
    final clock = TrustedClock(source);
    await clock.refresh();
    expect(clock.autoTime, isFalse);
  });
}
