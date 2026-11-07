import 'package:flutter/material.dart';

/// The prominent disclosure shown before Android's "Usage access" page, as
/// Google Play's User Data policy requires: what is read, why, where it
/// stays, and an explicit choice. Returns true only on ACCEPT.
Future<bool> showUsageDisclosure(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Usage access: what the System reads'),
      content: const SingleChildScrollView(
        child: Text(
          'To lock the apps you choose, Do or Die needs Android\'s "Usage '
          'access". With it, the app reads which app is in front and for how '
          'long, and the list of apps installed on this phone.\n\n'
          'It uses this only to:\n'
          '• cover a locked app with the lock screen during a lock or a '
          'phone-free block;\n'
          '• measure your daily minutes on the apps you chose, for '
          'screen-time limits;\n'
          '• let you pick which apps to lock.\n\n'
          'This data never leaves your phone: the app has no internet '
          'access, and nothing is shared or sold. You can withdraw access at '
          'any time in Android Settings; locks and measured limits then stop '
          'working.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('NOT NOW'),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('ACCEPT'),
        ),
      ],
    ),
  );
  return ok == true;
}
