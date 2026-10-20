import 'package:do_or_die/domain/block_list.dart';
import 'package:do_or_die/domain/day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const monday = DayKey(2026, 10, 19);
  final tuesday = monday.addDays(1);
  const insta = 'com.instagram.android';
  const yt = 'com.google.android.youtube';
  const bgmi = 'com.pubg.imobile';

  test('the user chooses the apps; nothing is fixed', () {
    final list = BlockList.initial(monday, {insta});
    expect(list.packagesOn(monday), {insta});
  });

  test('adding an app applies immediately', () {
    final list = BlockList.initial(monday, {insta}).add(monday, yt);
    expect(list.packagesOn(monday), {insta, yt});
    expect(list.packagesOn(tuesday), {insta, yt});
  });

  test('removing an app only applies from the next day', () {
    final list = BlockList.initial(monday, {insta, yt}).remove(monday, yt);
    expect(list.packagesOn(monday), {insta, yt});
    expect(list.packagesOn(tuesday), {insta});
  });

  test(
    'an app added today also stays in a removal already queued for tomorrow',
    () {
      final list = BlockList.initial(monday, {
        insta,
        yt,
      }).remove(monday, yt).add(monday, bgmi);
      expect(list.packagesOn(monday), {insta, yt, bgmi});
      expect(list.packagesOn(tuesday), {insta, bgmi});
    },
  );

  test('protected apps can never be blocked', () {
    final list = BlockList.initial(monday, {
      insta,
      'com.android.settings',
      'com.google.android.dialer',
    }).add(monday, 'com.doordie.do_or_die');
    expect(list.packagesOn(monday), {insta});
  });
}
